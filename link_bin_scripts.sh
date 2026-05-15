#!/usr/bin/env bash

# Script to clean dead symlinks in ~/.local/bin and optionally /usr/local/bin
# and relink profile bin scripts
# Usage: ./link_bin_scripts.sh <profile_name> [--non-interactive] [--system]
#   --non-interactive: Skip all prompts (for automated deployment)
#   --system: Also link to /usr/local/bin (requires sudo)

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors via the shared library (TTY-aware).
# shellcheck disable=SC1091
. "$BASE_DIR/lib/log.sh"

# Parse arguments
PROFILE_NAME=""
NON_INTERACTIVE=false
LINK_SYSTEM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --system)
            LINK_SYSTEM=true
            shift
            ;;
        *)
            if [ -z "$PROFILE_NAME" ]; then
                PROFILE_NAME="$1"
            else
                echo -e "${RED}Error: Unknown argument '$1'${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if profile name is provided
if [ -z "$PROFILE_NAME" ]; then
    echo -e "${RED}Error: No profile name provided${NC}"
    echo "Usage: $0 <profile_name> [--non-interactive] [--system]"
    echo "Available profiles:"
    find "$BASE_DIR/profiles" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || echo "  No profiles found"
    exit 1
fi

PROFILE_BIN_DIR="$BASE_DIR/profiles/${PROFILE_NAME}/bin"
LOCAL_BIN_DIR="${HOME}/.local/bin"

# Ask if scripts should also be linked to /usr/local/bin (only in interactive mode)
if [ "$NON_INTERACTIVE" = false ] && [ "$LINK_SYSTEM" = false ]; then
    echo -e "${YELLOW}Link scripts to /usr/local/bin (system-wide) in addition to ~/.local/bin?${NC}"
    echo "This requires sudo privileges."
    read -p "Link to /usr/local/bin? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        LINK_SYSTEM=true
    fi
fi

if [ "$LINK_SYSTEM" = true ]; then
    SYSTEM_BIN_DIR="/usr/local/bin"
fi

# Validate profile exists and has bin directory
if [ ! -d "$BASE_DIR/profiles/${PROFILE_NAME}" ]; then
    echo -e "${RED}Error: Profile '${PROFILE_NAME}' does not exist${NC}"
    exit 1
fi

if [ ! -d "${PROFILE_BIN_DIR}" ]; then
    echo -e "${YELLOW}Warning: Profile '${PROFILE_NAME}' has no bin directory${NC}"
    exit 0
fi

# Resolve the profile's bin directory to its canonical path so the
# "is this link managed by us?" check below can compare against a stable
# prefix even if the user symlinked the repo or invoked it via a path with
# symlinks in it.
PROFILE_BIN_REAL="$(readlink -f -- "${PROFILE_BIN_DIR}" 2>/dev/null || echo "${PROFILE_BIN_DIR}")"

# Function to clean dead symlinks in a directory.
#
# Scope: only links whose target was inside *this* profile's bin/ directory.
# Without this filter the previous version removed every dead link in
# ~/.local/bin and /usr/local/bin — including legitimate user-installed
# symlinks that happen to point at currently-missing targets (USB-mounted
# tools, sibling repos checked out elsewhere, etc.).
clean_dead_links() {
    local bin_dir="$1"
    local use_sudo="$2"

    echo -e "${GREEN}Cleaning dead symlinks in ${bin_dir} (only ones pointing into ${PROFILE_NAME}/bin)...${NC}" >&2
    local dead_links_count=0

    while IFS= read -r -d '' link; do
        # Skip if target still exists.
        [ -e "$link" ] && continue
        # Read the symlink text (NOT readlink -f, which would resolve through
        # the broken link and return nothing). We compare prefixes against
        # both the literal stored path and the canonical real path so this
        # works for both absolute and relative-into-the-repo links.
        local stored
        stored="$(readlink -- "$link" 2>/dev/null || true)"
        case "$stored" in
            "${PROFILE_BIN_DIR}"/*|"${PROFILE_BIN_REAL}"/*) ;;
            *) continue ;;
        esac

        echo "  Removing dead link: $(basename -- "$link")" >&2
        if [ "$use_sudo" = true ]; then
            sudo rm -- "$link"
        else
            rm -- "$link"
        fi
        dead_links_count=$((dead_links_count + 1))
    done < <(find "${bin_dir}" -maxdepth 1 -type l -print0 2>/dev/null) || true

    if [ $dead_links_count -eq 0 ]; then
        echo "  No dead links pointing into ${PROFILE_NAME}/bin found" >&2
    else
        echo -e "  ${GREEN}Removed ${dead_links_count} dead link(s)${NC}" >&2
    fi

    echo "$dead_links_count"
}

# Unique suffix per call: timestamp + PID + monotonic counter. Without the
# counter, calling this inside a `for script in ...` loop produces multiple
# `.bak.<same-second>` filenames; the second `mv` overwrites the first
# backup. With the counter every call is distinct.
BACKUP_SUFFIX_COUNTER=0
backup_existing_target() {
    local target="$1"
    local use_sudo="$2"
    BACKUP_SUFFIX_COUNTER=$((BACKUP_SUFFIX_COUNTER + 1))
    local backup_target="${target}.bak.$(date +%Y%m%d_%H%M%S).${$}.${BACKUP_SUFFIX_COUNTER}"

    echo "  Moving existing $(basename -- "$target") to $(basename -- "$backup_target")" >&2
    if [ "$use_sudo" = true ]; then
        sudo mv -- "$target" "$backup_target"
    else
        mv -- "$target" "$backup_target"
    fi
}

# Function to link scripts to a directory
link_scripts() {
    local bin_dir="$1"
    local use_sudo="$2"

    echo -e "\n${GREEN}Linking scripts from ${PROFILE_NAME}/bin to ${bin_dir}...${NC}" >&2
    local linked_count=0
    local skipped_count=0

    for script in "${PROFILE_BIN_DIR}"/*; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")
            target="${bin_dir}/${script_name}"

            # Move conflicting links or files aside before creating the managed symlink.
            if [ -e "$target" ] || [ -L "$target" ]; then
                if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$script")" ]; then
                    echo "  Skipping ${script_name} (already linked correctly)" >&2
                    skipped_count=$((skipped_count + 1))
                    continue
                fi
                backup_existing_target "$target" "$use_sudo"
            fi

            # Create symlink
            if [ "$use_sudo" = true ]; then
                sudo ln -s "$script" "$target"
            else
                ln -s "$script" "$target"
            fi
            echo "  Linked: ${script_name}" >&2
            linked_count=$((linked_count + 1))
        fi
    done

    echo "${linked_count}:${skipped_count}"
}

# Create ~/.local/bin if it doesn't exist
mkdir -p "${LOCAL_BIN_DIR}"

# Step 1: Clean dead symlinks and link scripts to ~/.local/bin
total_dead_links=$(clean_dead_links "${LOCAL_BIN_DIR}" false)
link_result=$(link_scripts "${LOCAL_BIN_DIR}" false)
local_linked_count=$(echo "$link_result" | cut -d: -f1)
local_skipped_count=$(echo "$link_result" | cut -d: -f2)

# Step 2: If requested, also handle /usr/local/bin
system_dead_links=0
system_linked_count=0
system_skipped_count=0

if [ "$LINK_SYSTEM" = true ]; then
    echo -e "\n${YELLOW}Processing /usr/local/bin (requires sudo)...${NC}"
    system_dead_links=$(clean_dead_links "${SYSTEM_BIN_DIR}" true)
    link_result=$(link_scripts "${SYSTEM_BIN_DIR}" true)
    system_linked_count=$(echo "$link_result" | cut -d: -f1)
    system_skipped_count=$(echo "$link_result" | cut -d: -f2)
fi

# Summary
echo -e "\n${GREEN}Summary:${NC}"
echo "  ~/.local/bin:"
echo "    Cleaned: ${total_dead_links} dead link(s)"
echo "    Linked: ${local_linked_count} script(s)"
echo "    Skipped: ${local_skipped_count} (already correct)"

if [ "$LINK_SYSTEM" = true ]; then
    echo "  /usr/local/bin:"
    echo "    Cleaned: ${system_dead_links} dead link(s)"
    echo "    Linked: ${system_linked_count} script(s)"
    echo "    Skipped: ${system_skipped_count} (already correct)"
fi

echo -e "${GREEN}Done!${NC}"

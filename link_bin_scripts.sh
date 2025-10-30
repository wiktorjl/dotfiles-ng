#!/usr/bin/env bash

# Script to clean dead symlinks in ~/.local/bin and relink profile bin scripts
# Usage: ./link_bin_scripts.sh <profile_name>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if profile name is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No profile name provided${NC}"
    echo "Usage: $0 <profile_name>"
    echo "Available profiles:"
    ls -d profiles/*/ 2>/dev/null | xargs -n1 basename || echo "  No profiles found"
    exit 1
fi

PROFILE_NAME="$1"
PROFILE_BIN_DIR="$(pwd)/profiles/${PROFILE_NAME}/bin"
LOCAL_BIN_DIR="${HOME}/.local/bin"

# Validate profile exists and has bin directory
if [ ! -d "profiles/${PROFILE_NAME}" ]; then
    echo -e "${RED}Error: Profile '${PROFILE_NAME}' does not exist${NC}"
    exit 1
fi

if [ ! -d "${PROFILE_BIN_DIR}" ]; then
    echo -e "${YELLOW}Warning: Profile '${PROFILE_NAME}' has no bin directory${NC}"
    exit 0
fi

# Create ~/.local/bin if it doesn't exist
mkdir -p "${LOCAL_BIN_DIR}"

# Step 1: Clean dead symlinks in ~/.local/bin
echo -e "${GREEN}Cleaning dead symlinks in ${LOCAL_BIN_DIR}...${NC}"
dead_links_count=0
while IFS= read -r -d '' link; do
    if [ ! -e "$link" ]; then
        echo "  Removing dead link: $(basename "$link")"
        rm "$link"
        dead_links_count=$((dead_links_count + 1))
    fi
done < <(find "${LOCAL_BIN_DIR}" -maxdepth 1 -type l -print0 2>/dev/null) || true

if [ $dead_links_count -eq 0 ]; then
    echo "  No dead links found"
else
    echo -e "  ${GREEN}Removed ${dead_links_count} dead link(s)${NC}"
fi

# Step 2: Link all scripts from profile bin directory
echo -e "\n${GREEN}Linking scripts from ${PROFILE_NAME}/bin...${NC}"
linked_count=0
skipped_count=0

for script in "${PROFILE_BIN_DIR}"/*; do
    if [ -f "$script" ]; then
        script_name=$(basename "$script")
        target="${LOCAL_BIN_DIR}/${script_name}"

        # Remove existing link or file if it exists
        if [ -e "$target" ] || [ -L "$target" ]; then
            if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$script")" ]; then
                echo "  Skipping ${script_name} (already linked correctly)"
                skipped_count=$((skipped_count + 1))
                continue
            fi
            echo "  Removing existing: ${script_name}"
            rm "$target"
        fi

        # Create symlink
        ln -s "$script" "$target"
        echo "  Linked: ${script_name}"
        linked_count=$((linked_count + 1))
    fi
done

echo -e "\n${GREEN}Summary:${NC}"
echo "  Cleaned: ${dead_links_count} dead link(s)"
echo "  Linked: ${linked_count} script(s)"
echo "  Skipped: ${skipped_count} (already correct)"
echo -e "${GREEN}Done!${NC}"

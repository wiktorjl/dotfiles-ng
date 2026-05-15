#!/bin/bash

# Handle the label argument for the menu
if [ "$1" == "-l" ]; then
    echo "sysrod - System Status"
    exit 0
fi

# Cache configuration
CACHE_DIR="${HOME}/.cache/sysrod"
CACHE_FILE="${CACHE_DIR}/status.cache"
CACHE_MAX_AGE=900  # 15 minutes in seconds

# ASCII Art and Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
DECO_LEFT="<~>"
DECO_RIGHT="<~>"

# Function to trigger background update
trigger_update() {
    # Get the absolute path to the update script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    UPDATE_SCRIPT="${SCRIPT_DIR}/update_sysrod_cache.sh"

    # Fallback to ~/.local/bin if not found in script directory
    if [ ! -x "$UPDATE_SCRIPT" ]; then
        UPDATE_SCRIPT="${HOME}/.local/bin/update_sysrod_cache.sh"
    fi

    # Trigger background update if script exists
    if [ -x "$UPDATE_SCRIPT" ]; then
        "$UPDATE_SCRIPT" &>/dev/null &
        disown
    fi
}

# Function to get fallback status (basic system info without slow operations)
get_fallback_status() {
    USER_HOST="$(whoami)@$(hostname)"
    KERNEL=$(uname -r)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$NAME $VERSION_ID $VERSION_CODENAME"
    else
        DISTRO=$(cat /etc/*-release | head -n1)
    fi
    echo -e "${GREEN}${DECO_LEFT} ${USER_HOST} | ${DISTRO} | KERNEL: ${KERNEL} ${DECO_RIGHT}${NC} ${YELLOW}[UPDATING...]${NC}"
}

# Check if cache exists and is fresh. The cache format is:
#   line 1: unix timestamp
#   line 2: literal "---" separator
#   line 3..: rendered status (already contains escape sequences)
# We deliberately read it as data — never `source` it — because the writer
# embeds $(hostname) and other unsanitised values.
if [ -f "$CACHE_FILE" ]; then
    TIMESTAMP=""
    STATUS_LINE=""
    if IFS= read -r TIMESTAMP < "$CACHE_FILE" && [[ "$TIMESTAMP" =~ ^[0-9]+$ ]]; then
        STATUS_LINE=$(tail -n +3 "$CACHE_FILE")
    fi

    if [ -z "$TIMESTAMP" ] || [ -z "$STATUS_LINE" ]; then
        # Corrupt cache - treat as missing
        get_fallback_status
        trigger_update
    else
        CURRENT_TIME=$(date +%s)
        CACHE_AGE=$((CURRENT_TIME - TIMESTAMP))

        if [ $CACHE_AGE -lt $CACHE_MAX_AGE ]; then
            echo -e "${STATUS_LINE}"
        else
            echo -e "${STATUS_LINE} ${YELLOW}[STALE - updating...]${NC}"
            trigger_update
        fi
    fi
else
    # No cache exists - show fallback and trigger initial update
    get_fallback_status
    trigger_update
fi

echo

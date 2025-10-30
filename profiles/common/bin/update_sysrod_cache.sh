#!/bin/bash

# Script to update the sysrod cache with system status information
# This script contains all the slow operations (network calls, multiple subprocesses)
# and should be run in the background to avoid blocking shell startup

set -euo pipefail

CACHE_DIR="${HOME}/.cache/sysrod"
CACHE_FILE="${CACHE_DIR}/status.cache"
LOCK_FILE="${CACHE_DIR}/update.lock"

# Create cache directory if it doesn't exist
mkdir -p "${CACHE_DIR}"

# Use flock to prevent multiple concurrent updates
# Exit silently if another update is already running
exec 200>"${LOCK_FILE}"
flock -n 200 || exit 0

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color
DECO_LEFT="<~>"
DECO_RIGHT="<~>"

# --- Gather Information ---

# User and Host
USER_HOST="$(whoami)@$(hostname)"

# Kernel and Distribution
KERNEL=$(uname -r)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$NAME $VERSION_ID $VERSION_CODENAME"
else
    DISTRO=$(cat /etc/*-release | head -n1)
fi

# CPU Load (1-minute average)
CPU_LOAD=$(uptime | awk -F'load average: ' '{print $2}' | cut -d, -f1)

# Memory Load (Used/Total)
MEM_INFO=$(free -m | awk 'NR==2{printf "%.0f%% (%sM/%sM)", $3*100/$2, $3, $2}')

# Disk Space Free (For root partition)
DISK_FREE=$(df -h / | awk 'NR==2{print $4}')

# Logged in Users
USERS=$(who -q | tail -n1 | cut -d'=' -f2)

# Uptime
UPTIME=$(uptime -p | sed 's/up //')

# Running Processes
PROCESSES=$(ps -e --no-headers | wc -l)

# Virtual Environment Check - Optimized
VIRT_ENV="None"
# Check for Docker (fast check)
if [ -f /.dockerenv ]; then
    VIRT_ENV="Docker"
# Check systemd-detect-virt first (much faster than dmesg/lspci)
elif command -v systemd-detect-virt &>/dev/null; then
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT_TYPE" != "none" ] && [ -n "$VIRT_TYPE" ]; then
        VIRT_ENV="$VIRT_TYPE"
    fi
# Fallback to checking /proc/cpuinfo for hypervisor flag (faster than dmesg)
elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
    VIRT_ENV="VM"
fi || true

# Dotfiles Status Check
DOTFILES_STATUS=""
if [ -d "$HOME/dotfiles-ng" ]; then
    # Get the absolute path to the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -x "$SCRIPT_DIR/check_dotfiles_status.sh" ]; then
        DOTFILES_STATUS=$("$SCRIPT_DIR/check_dotfiles_status.sh" 2>/dev/null || echo "Dotfiles: error")
    else
        # Fallback: try to find it in ~/.local/bin
        if [ -x "$HOME/.local/bin/check_dotfiles_status.sh" ]; then
            DOTFILES_STATUS=$("$HOME/.local/bin/check_dotfiles_status.sh" 2>/dev/null || echo "Dotfiles: error")
        else
            DOTFILES_STATUS="Dotfiles: script not found"
        fi
    fi
else
    DOTFILES_STATUS="Dotfiles: not found"
fi

# Additional colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'

# Symbols
SYMBOL_SYSTEM="▸"
SYMBOL_RESOURCE="●"
SYMBOL_STATUS="◆"

# Build the status output with sections
SECTION_SYSTEM="${BOLD}${GREEN}${SYMBOL_SYSTEM} SYSTEM${NC}"
LINE_SYSTEM="  ${GREEN}${USER_HOST}${NC} ${DIM}|${NC} ${DISTRO} ${DIM}|${NC} ${KERNEL}"

SECTION_RESOURCES="${BOLD}${CYAN}${SYMBOL_RESOURCE} RESOURCES${NC}"
LINE_RES1="  CPU ${CPU_LOAD}  ${DIM}•${NC}  MEM ${MEM_INFO}  ${DIM}•${NC}  DISK ${DISK_FREE} free"
LINE_RES2="  PROC ${PROCESSES}  ${DIM}•${NC}  USERS ${USERS}"

SECTION_STATUS="${BOLD}${YELLOW}${SYMBOL_STATUS} STATUS${NC}"
LINE_STAT1="  Uptime: ${UPTIME}"
LINE_STAT2="  Virtualization: ${VIRT_ENV}"
LINE_STAT3="  ${DOTFILES_STATUS}"

# Build the complete status output
STATUS_LINE="${SECTION_SYSTEM}
${LINE_SYSTEM}

${SECTION_RESOURCES}
${LINE_RES1}
${LINE_RES2}

${SECTION_STATUS}
${LINE_STAT1}
${LINE_STAT2}
${LINE_STAT3}"

# Write to cache file atomically (write to temp file, then move)
TEMP_FILE="${CACHE_FILE}.tmp.$$"
cat > "${TEMP_FILE}" <<EOF
TIMESTAMP=$(date +%s)
STATUS_LINE='${STATUS_LINE}'
EOF

mv "${TEMP_FILE}" "${CACHE_FILE}"

# Release lock
flock -u 200

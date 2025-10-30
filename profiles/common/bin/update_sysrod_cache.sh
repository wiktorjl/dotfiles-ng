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

# Build the status line
STATUS_LINE="${GREEN}${DECO_LEFT} ${USER_HOST} | ${DISTRO} | KERNEL: ${KERNEL} | CPU: ${CPU_LOAD} | MEM: ${MEM_INFO} | DISK: ${DISK_FREE} free | USERS: ${USERS} | PROC: ${PROCESSES} | UPTIME: ${UPTIME} | VIRT: ${VIRT_ENV} | ${DOTFILES_STATUS} ${DECO_RIGHT}${NC}"

# Write to cache file atomically (write to temp file, then move)
TEMP_FILE="${CACHE_FILE}.tmp.$$"
cat > "${TEMP_FILE}" <<EOF
TIMESTAMP=$(date +%s)
STATUS_LINE='${STATUS_LINE}'
EOF

mv "${TEMP_FILE}" "${CACHE_FILE}"

# Release lock
flock -u 200

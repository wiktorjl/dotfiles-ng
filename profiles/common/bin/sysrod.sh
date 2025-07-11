#!/bin/bash

# Handle the label argument for the menu
if [ "$1" == "-l" ]; then
    echo "sysrod - System Status"
    exit 0
fi

# ASCII Art and Colors
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
    DISTRO="$NAME $VERSION_ID"
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

# Virtual Environment Check
VIRT_ENV="None"
# Check for Docker
if [ -f /.dockerenv ]; then
    VIRT_ENV="Docker"
# Check for QEMU/KVM
elif [[ $(dmesg 2>/dev/null | grep "Hypervisor detected") =~ "KVM" || $(lspci 2>/dev/null | grep "Red Hat, Inc. Virtio") ]]; then
    VIRT_ENV="QEMU/KVM"
fi


# --- Display Output ---
echo -e "${GREEN}${DECO_LEFT} ${USER_HOST} | ${DISTRO} | KERNEL: ${KERNEL} | CPU: ${CPU_LOAD} | MEM: ${MEM_INFO} | DISK: ${DISK_FREE} free | USERS: ${USERS} | PROC: ${PROCESSES} | UPTIME: ${UPTIME} | VIRT: ${VIRT_ENV} ${DECO_RIGHT}${NC}"

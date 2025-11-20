#!/bin/bash

# Script to list IP addresses of KVM virtual machines
# Usage:
#   list_kvm_ips.sh [OPTIONS] [VM_NAME]
#
# Options:
#   --method virsh      Use virsh domifaddr (default)
#   --method arp-file   Use ARP leases file (/var/lib/arpalert/arpalert.leases)
#   -h, --help          Show this help message
#
# Output format: VMNAME    IP_ADDRESS    MAC_ADDRESS    SOURCE    INTERFACE

# --- Configuration ---
LEASES_FILE="/var/lib/arpalert/arpalert.leases"
METHOD="virsh"
VM_NAME=""

# --- Parse arguments ---
show_help() {
    sed -n '3,12p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --method)
            METHOD="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            show_help
            ;;
        *)
            VM_NAME="$1"
            shift
            ;;
    esac
done

# Validate method
if [[ "$METHOD" != "virsh" && "$METHOD" != "arp-file" ]]; then
    echo "Error: Invalid method '$METHOD'. Use 'virsh' or 'arp-file'" >&2
    exit 1
fi

# --- Method 1: virsh domifaddr ---
get_vm_ips_virsh() {
    local vm="$1"

    # Check if VM is running
    local state
    state=$(sudo virsh domstate "$vm" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "Error: VM '$vm' not found" >&2
        return 1
    fi

    if [[ "$state" != "running" ]]; then
        printf "%-20s %-15s %-17s %-8s %s\n" "$vm" "-" "-" "-" "(not running)"
        return 0
    fi

    # Get IP addresses using ARP source
    local output
    output=$(sudo virsh domifaddr "$vm" --full --source arp 2>/dev/null)

    if [[ $? -eq 0 && -n "$output" ]]; then
        # Skip the header lines and parse interface info
        echo "$output" | tail -n +3 | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Parse the line: interface mac protocol ip/prefix
            read -r iface mac protocol ipcidr <<< "$line"
            # Extract just the IP without CIDR notation
            ip="${ipcidr%/*}"
            printf "%-20s %-15s %-17s %-8s %s\n" "$vm" "$ip" "$mac" "$protocol" "$iface"
        done
    else
        printf "%-20s %-15s %-17s %-8s %s\n" "$vm" "-" "-" "-" "(no IP found)"
    fi
}

# --- Method 2: ARP leases file ---
get_vm_ips_arp_file() {
    local target_vm="$1"

    # Check if the leases file exists and is readable
    if [[ ! -r "$LEASES_FILE" ]]; then
        echo "Error: Leases file not found or not readable at $LEASES_FILE" >&2
        exit 1
    fi

    # Create an associative array to hold MAC-to-IP mappings
    declare -A leases_map

    # Read the ARP lease file
    # Format: MAC IP INTERFACE TIMESTAMP SEQUENCE
    while read -r mac ip _; do
        leases_map[${mac,,}]=$ip
    done < "$LEASES_FILE"

    # Process VMs
    while read -r vmname; do
        [[ -z "$vmname" ]] && continue

        # Skip if target VM specified and this isn't it
        if [[ -n "$target_vm" && "$vmname" != "$target_vm" ]]; then
            continue
        fi

        # Check VM state
        if [[ "$(virsh domstate "$vmname" 2>/dev/null)" == "running" ]]; then
            # Get interfaces
            virsh domiflist "$vmname" | tail -n +3 | head -n -1 | while read -r iface type network model mac state; do
                [[ -z "$mac" ]] && continue

                mac_lower=${mac,,}
                ip=${leases_map[$mac_lower]}

                if [[ -n "$ip" ]]; then
                    printf "%-20s %-15s %-17s %-8s %s\n" "$vmname" "$ip" "$mac" "arp" "$iface"
                fi
            done
        fi
    done < <(virsh list --all --name)
}

# --- Main logic ---
if [[ "$METHOD" == "virsh" ]]; then
    if [[ -n "$VM_NAME" ]]; then
        # Single VM specified
        get_vm_ips_virsh "$VM_NAME"
    else
        # List all running VMs
        mapfile -t running_vms < <(sudo virsh list --name 2>/dev/null | grep -v '^$')

        if [[ ${#running_vms[@]} -eq 0 ]]; then
            echo "No running VMs found"
            exit 0
        fi

        for vm in "${running_vms[@]}"; do
            [[ -z "$vm" ]] && continue
            get_vm_ips_virsh "$vm"
        done
    fi
else
    # ARP file method
    get_vm_ips_arp_file "$VM_NAME"
fi

#!/bin/bash

# Script to list IP addresses of KVM virtual machines
# Usage:
#   list_kvm_ips.sh          # List IPs for all running VMs
#   list_kvm_ips.sh <vm-name> # List IPs for specific VM

VM_NAME="${1:-}"

# Function to get and display IP addresses for a VM
get_vm_ips() {
    local vm="$1"

    # Check if VM is running
    local state
    state=$(sudo virsh domstate "$vm" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "Error: VM '$vm' not found" >&2
        return 1
    fi

    if [[ "$state" != "running" ]]; then
        echo "VM: $vm (not running)"
        return 0
    fi

    echo "VM: $vm"

    # Get IP addresses using ARP source
    local output
    output=$(sudo virsh domifaddr "$vm" --full --source arp 2>/dev/null)

    if [[ $? -eq 0 && -n "$output" ]]; then
        # Skip the header lines and display interface info
        echo "$output" | tail -n +3 | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            echo "  $line"
        done
    else
        echo "  No IP addresses found"
    fi

    echo ""
}

# Main logic
if [[ -n "$VM_NAME" ]]; then
    # Single VM specified
    get_vm_ips "$VM_NAME"
else
    # List all running VMs
    mapfile -t running_vms < <(sudo virsh list --name 2>/dev/null | grep -v '^$')

    if [[ ${#running_vms[@]} -eq 0 ]]; then
        echo "No running VMs found"
        exit 0
    fi

    for vm in "${running_vms[@]}"; do
        [[ -z "$vm" ]] && continue
        get_vm_ips "$vm"
    done
fi

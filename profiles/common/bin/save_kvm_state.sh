#!/bin/bash

# Script to save the state of running KVM virtual machines
# NOTE: This uses 'virsh managedsave' which suspends VMs and saves state
#       Restore with: virsh start <vm-name>
# Usage:
#   save_kvm_state.sh [OPTIONS]
#
# Options:
#   --verify-network           Only save VMs that have network connectivity (via ARP)
#   --dry-run                  Show what would be done without doing it
#   --vm <name>                Only save specific VM
#   -h, --help                 Show this help message
#
# Examples:
#   save_kvm_state.sh                              # Save all running VMs
#   save_kvm_state.sh --verify-network             # Only VMs with network connectivity
#   save_kvm_state.sh --vm myvm                    # Save specific VM
#
# Note: Managed save files are stored in /VM/kvm/saves/

# --- Configuration ---
LEASES_FILE="/var/lib/arpalert/arpalert.leases"
VERIFY_NETWORK=false
DRY_RUN=false
TARGET_VM=""

# --- Parse arguments ---
show_help() {
    sed -n '3,18p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify-network)
            VERIFY_NETWORK=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --vm)
            TARGET_VM="$2"
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
            echo "Error: Unexpected argument $1" >&2
            show_help
            ;;
    esac
done

# --- Get VMs with network connectivity (via ARP) ---
get_network_vms() {
    declare -a network_vms

    # Check if the leases file exists and is readable
    if [[ ! -r "$LEASES_FILE" ]]; then
        echo "Warning: Leases file not found at $LEASES_FILE, skipping network verification" >&2
        return 1
    fi

    # Create an associative array to hold MAC-to-VM mappings
    declare -A vm_macs

    # Get all running VMs and their MAC addresses
    while read -r vmname; do
        [[ -z "$vmname" ]] && continue

        if [[ "$(virsh domstate "$vmname" 2>/dev/null)" == "running" ]]; then
            # Get MAC addresses for this VM
            while read -r line; do
                mac=$(echo "$line" | awk '{print $5}')
                [[ -z "$mac" ]] && continue
                vm_macs[${mac,,}]="$vmname"
            done < <(virsh domiflist "$vmname" | tail -n +3 | head -n -1)
        fi
    done < <(virsh list --all --name)

    # Read the ARP lease file and match MACs
    while read -r mac ip _; do
        mac_lower=${mac,,}
        if [[ -n "${vm_macs[$mac_lower]}" ]]; then
            vmname="${vm_macs[$mac_lower]}"
            # Add to network_vms if not already present
            if [[ ! " ${network_vms[@]} " =~ " ${vmname} " ]]; then
                network_vms+=("$vmname")
            fi
        fi
    done < "$LEASES_FILE"

    # Return the list
    printf '%s\n' "${network_vms[@]}"
}

# --- Save VM state ---
save_vm_state() {
    local vm="$1"

    # Check if VM exists and is running
    local state
    state=$(virsh domstate "$vm" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "Error: VM '$vm' not found" >&2
        return 1
    fi

    if [[ "$state" != "running" ]]; then
        echo "Skipping '$vm': not running (state: $state)"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would managedsave VM '$vm'"
        return 0
    fi

    echo "Saving state for VM '$vm'..."
    echo "  (VM will be suspended)"

    # Save VM state using managedsave - libvirt manages the save file
    if sudo virsh managedsave "$vm" 2>/dev/null; then
        echo "  ✓ Successfully saved state for '$vm'"
        echo "  Restore with: sudo virsh start $vm"
        return 0
    else
        echo "  ✗ Failed to save state for '$vm'" >&2
        return 1
    fi
}

# --- Main logic ---
echo "KVM State Save Tool"
echo "==================="
echo "Save location: /VM/kvm/saves/"
[[ "$DRY_RUN" == true ]] && echo "Mode: DRY RUN"
echo ""
echo "WARNING: VMs will be suspended when their state is saved!"
echo "Restore with: sudo virsh start <vm-name>"
echo ""

# Determine which VMs to save
declare -a vms_to_save

if [[ -n "$TARGET_VM" ]]; then
    # Single VM specified
    vms_to_save=("$TARGET_VM")
    echo "Target: Single VM '$TARGET_VM'"
elif [[ "$VERIFY_NETWORK" == true ]]; then
    # Only VMs with network connectivity
    echo "Method: Virsh + ARP verification (network-connected VMs only)"
    mapfile -t vms_to_save < <(get_network_vms)

    if [[ ${#vms_to_save[@]} -eq 0 ]]; then
        echo "No VMs found with network connectivity"
        exit 0
    fi
else
    # All running VMs from virsh
    echo "Method: Virsh (all running VMs)"
    mapfile -t vms_to_save < <(virsh list --name 2>/dev/null | grep -v '^$')

    if [[ ${#vms_to_save[@]} -eq 0 ]]; then
        echo "No running VMs found"
        exit 0
    fi
fi

echo "VMs to save: ${#vms_to_save[@]}"
echo ""

# Save VM states
success_count=0
fail_count=0

for vm in "${vms_to_save[@]}"; do
    [[ -z "$vm" ]] && continue

    if save_vm_state "$vm"; then
        ((success_count++))
    else
        ((fail_count++))
    fi
done

echo ""
echo "Summary"
echo "-------"
echo "Successful: $success_count"
echo "Failed: $fail_count"
echo "Total: $((success_count + fail_count))"

[[ $fail_count -gt 0 ]] && exit 1
exit 0

#!/usr/bin/env bash
set -euo pipefail

# Script to update /etc/hosts with KVM VM hostnames and IPs
# Usage:
#   update_kvm_hosts.sh [OPTIONS]
#
# Options:
#   --dry-run       Preview changes without modifying /etc/hosts
#   -h, --help      Show this help message
#
# This script:
#   - Queries running KVM VMs and their IP addresses
#   - Updates /etc/hosts with VM entries (marked with # kvm-hosts)
#   - Removes entries for deleted VMs
#   - Keeps entries for stopped VMs
#   - Detects IP/hostname conflicts between running VMs
#   - Creates timestamped backup before modifying /etc/hosts

TAG="# kvm-hosts"
HOSTS_FILE="/etc/hosts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_KVM_IPS_SCRIPT="$SCRIPT_DIR/list_kvm_ips.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DRY_RUN=false
BACKUP_FILE=""
SEPARATOR=""
declare -A running_vms
declare -A running_vm_set
declare -A all_vms
declare -A managed_entry_seen
declare -A keep_entry
declare -A add_entry
declare -A removed_entry
managed_entry_ips=()
managed_entry_vms=()
file_lines=()
file_line_types=()
file_line_keys=()

show_help() {
    sed -n '4,11p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

check_requirements() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run with sudo${NC}"
        echo "Usage: sudo $0 [--dry-run]"
        exit 1
    fi

    if ! command -v virsh &> /dev/null; then
        echo -e "${RED}Error: virsh command not found${NC}"
        echo "Please install libvirt packages"
        exit 1
    fi

    if [ ! -x "$LIST_KVM_IPS_SCRIPT" ]; then
        echo -e "${RED}Error: $LIST_KVM_IPS_SCRIPT not found or not executable${NC}"
        exit 1
    fi

    if [ ! -r "$HOSTS_FILE" ] || [ ! -w "$HOSTS_FILE" ]; then
        echo -e "${RED}Error: Cannot read or write $HOSTS_FILE${NC}"
        exit 1
    fi
}

get_running_vms() {
    local output
    if ! output=$("$LIST_KVM_IPS_SCRIPT" --method virsh 2>&1); then
        echo -e "${RED}Error: Failed to get VM IPs${NC}" >&2
        echo "$output" >&2
        exit 1
    fi

    if [[ "$output" == *"No running VMs found"* ]]; then
        echo "No running VMs found"
        return 0
    fi

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == "VMNAME"* ]] && continue
        [[ "$line" == *"(not running)"* ]] && continue
        [[ "$line" == *"(no IP found)"* ]] && continue

        local vm_name ip
        read -r vm_name ip _ <<< "$line"

        [[ -z "$vm_name" || -z "$ip" || "$ip" == "-" ]] && continue

        running_vm_set["$vm_name"]=true
        if [ -n "${running_vms[$vm_name]:-}" ]; then
            running_vms[$vm_name]="${running_vms[$vm_name]} $ip"
        else
            running_vms[$vm_name]="$ip"
        fi
    done <<< "$output"
}

get_all_vms() {
    local output
    if ! output=$(virsh list --all --name 2>&1); then
        echo -e "${RED}Error: Failed to get VM list${NC}" >&2
        echo "$output" >&2
        exit 1
    fi

    while IFS= read -r vm_name; do
        [[ -z "$vm_name" ]] && continue
        all_vms["$vm_name"]=true
    done <<< "$output"
}

parse_hosts_file() {
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == *"$TAG"* ]]; then
            if [[ "$line" =~ ^[[:space:]]*([^[:space:]]+)([[:space:]]+)([^[:space:]]+) ]]; then
                local ip="${BASH_REMATCH[1]}"
                local sep="${BASH_REMATCH[2]}"
                local vm_name="${BASH_REMATCH[3]}"
                local key="${ip}|${vm_name}"

                if [[ -z "${managed_entry_seen[$key]:-}" ]]; then
                    managed_entry_seen["$key"]=true
                    managed_entry_ips+=("$ip")
                    managed_entry_vms+=("$vm_name")
                    file_lines+=("$line")
                    file_line_types+=("managed")
                    file_line_keys+=("$key")
                else
                    file_lines+=("$line")
                    file_line_types+=("duplicate")
                    file_line_keys+=("$key")
                fi

                if [[ -z "$SEPARATOR" ]]; then
                    SEPARATOR="$sep"
                fi
            else
                file_lines+=("$line")
                file_line_types+=("unmanaged")
                file_line_keys+=("")
            fi
        else
            file_lines+=("$line")
            file_line_types+=("unmanaged")
            file_line_keys+=("")
        fi
    done < "$HOSTS_FILE"

    if [[ -z "$SEPARATOR" ]]; then
        SEPARATOR=$'\t'
    fi
}

show_conflict_error() {
    local conflict_type="$1"
    local vm1="$2"
    local ip1="$3"
    local vm2="$4"
    local ip2="$5"
    local running1="$6"
    local running2="$7"

    echo -e "${RED}ERROR: $conflict_type detected${NC}"
    echo ""
    if [ "$ip1" != "-" ]; then
        echo "Conflicting IP: $ip1"
        echo "  VM '$vm1' has IP $ip1 ($running1)"
        echo "  VM '$vm2' has IP $ip2 ($running2)"
    else
        echo "Conflicting hostname: $vm1"
        echo "  VM '$vm1' ($running1)"
        echo "  VM '$vm2' ($running2)"
    fi
    echo ""
    echo "Both VMs are running. Please resolve the conflict and try again."
    exit 1
}

detect_conflicts() {
    declare -A ip_to_vm
    declare -A hostname_to_vm

    for vm_name in "${!running_vms[@]}"; do
        local hostname="$vm_name"
        if [[ -n "${hostname_to_vm[$hostname]:-}" ]] && [ "${hostname_to_vm[$hostname]}" != "$vm_name" ]; then
            show_conflict_error "Hostname conflict between running VMs" \
                "$vm_name" "-" "${hostname_to_vm[$hostname]}" "-" \
                "running" "running"
        fi
        hostname_to_vm["$hostname"]="$vm_name"

        local ips
        IFS=' ' read -ra ips <<< "${running_vms[$vm_name]}"
        for ip in "${ips[@]}"; do
            if [[ -n "${ip_to_vm[$ip]:-}" ]] && [ "${ip_to_vm[$ip]}" != "$vm_name" ]; then
                show_conflict_error "IP conflict between running VMs" \
                    "$vm_name" "$ip" "${ip_to_vm[$ip]}" "$ip" \
                    "running" "running"
            fi
            ip_to_vm["$ip"]="$vm_name"
        done
    done
}

vm_has_ip() {
    local vm_name="$1"
    local ip="$2"
    local ips

    IFS=' ' read -ra ips <<< "${running_vms[$vm_name]:-}"
    for test_ip in "${ips[@]}"; do
        if [ "$test_ip" == "$ip" ]; then
            return 0
        fi
    done
    return 1
}

determine_changes() {
    local count=${#managed_entry_ips[@]}
    local i=0

    while [ $i -lt $count ]; do
        local ip="${managed_entry_ips[$i]}"
        local vm_name="${managed_entry_vms[$i]}"
        local key="${ip}|${vm_name}"

        if [[ "${all_vms[$vm_name]:-false}" != "true" ]]; then
            removed_entry["$key"]=true
        elif [[ "${running_vm_set[$vm_name]:-false}" == "true" ]]; then
            if vm_has_ip "$vm_name" "$ip"; then
                keep_entry["$key"]=true
            else
                removed_entry["$key"]=true
            fi
        else
            keep_entry["$key"]=true
        fi

        i=$((i + 1))
    done

    for vm_name in "${!running_vms[@]}"; do
        local ips
        IFS=' ' read -ra ips <<< "${running_vms[$vm_name]}"
        for ip in "${ips[@]}"; do
            local key="${ip}|${vm_name}"
            if [[ -z "${keep_entry[$key]:-}" ]]; then
                add_entry["$key"]="${ip}|${vm_name}"
            fi
        done
    done
}

show_dry_run() {
    echo "DRY RUN - Changes to be applied:"
    echo ""

    local add_count=0
    local remove_count=0
    local keep_count=0

    for key in "${!add_entry[@]}"; do
        add_count=$((add_count + 1))
    done

    for key in "${!removed_entry[@]}"; do
        remove_count=$((remove_count + 1))
    done

    for key in "${!keep_entry[@]}"; do
        keep_count=$((keep_count + 1))
    done

    if [ $add_count -gt 0 ]; then
        echo "  Would add: $add_count entries"
        for key in "${!add_entry[@]}"; do
            local ip="${key%%|*}"
            local vm_name="${key#*|}"
            echo "    - $vm_name ($ip)"
        done
    fi

    if [ $remove_count -gt 0 ]; then
        echo "  Would remove: $remove_count entries"
        for key in "${!removed_entry[@]}"; do
            local ip="${key%%|*}"
            local vm_name="${key#*|}"
            echo "    - $vm_name ($ip)"
        done
    fi

    if [ $add_count -eq 0 ] && [ $remove_count -eq 0 ]; then
        echo "  Would keep: $keep_count entries"
    fi

    echo ""
    echo "No changes were made."
}

create_backup() {
    BACKUP_FILE="${HOSTS_FILE}.backup$(date +%Y%m%d_%H%M%S)"
    if ! cp "$HOSTS_FILE" "$BACKUP_FILE"; then
        echo -e "${RED}Error: Failed to create backup${NC}" >&2
        exit 1
    fi
}

generate_new_hosts() {
    local new_lines=()

    local count=${#file_lines[@]}
    local i=0
    while [ $i -lt $count ]; do
        local line="${file_lines[$i]}"
        local line_type="${file_line_types[$i]}"
        local key="${file_line_keys[$i]}"

        if [ "$line_type" == "unmanaged" ]; then
            new_lines+=("$line")
        elif [ "$line_type" == "managed" ]; then
            if [[ "${keep_entry[$key]:-false}" == "true" ]]; then
                new_lines+=("$line")
            fi
        fi

        i=$((i + 1))
    done

    for key in "${!add_entry[@]}"; do
        local ip="${key%%|*}"
        local vm_name="${key#*|}"
        new_lines+=("$ip${SEPARATOR}$vm_name${SEPARATOR}$TAG")
    done

    for line in "${new_lines[@]}"; do
        echo "$line"
    done
}

apply_changes() {
    local temp_file="/tmp/hosts.new.$$"
    generate_new_hosts > "$temp_file"

    if [ ! -s "$temp_file" ]; then
        echo -e "${RED}Error: Generated empty hosts file${NC}"
        rm -f "$temp_file"
        exit 1
    fi

    if ! mv "$temp_file" "$HOSTS_FILE"; then
        echo -e "${RED}Error: Failed to update $HOSTS_FILE${NC}" >&2
        rm -f "$temp_file"
        exit 1
    fi
}

show_summary() {
    echo "KVM VMs /etc/hosts update summary:"
    echo ""

    local add_count=0
    local remove_count=0
    local keep_count=0

    for key in "${!add_entry[@]}"; do
        add_count=$((add_count + 1))
    done

    for key in "${!removed_entry[@]}"; do
        remove_count=$((remove_count + 1))
    done

    for key in "${!keep_entry[@]}"; do
        keep_count=$((keep_count + 1))
    done

    if [ $add_count -gt 0 ]; then
        echo -e "  ${GREEN}Added:${NC} $add_count entries"
        for key in "${!add_entry[@]}"; do
            local ip="${key%%|*}"
            local vm_name="${key#*|}"
            echo "    - $vm_name ($ip)"
        done
    fi

    if [ $remove_count -gt 0 ]; then
        echo -e "  ${YELLOW}Removed:${NC} $remove_count entries"
        for key in "${!removed_entry[@]}"; do
            local ip="${key%%|*}"
            local vm_name="${key#*|}"
            echo "    - $vm_name ($ip)"
        done
    fi

    if [ $add_count -eq 0 ] && [ $remove_count -eq 0 ]; then
        echo -e "  ${GREEN}Unchanged:${NC} $keep_count entries"
    fi

    if [ -n "$BACKUP_FILE" ]; then
        echo ""
        echo "Backup created: $BACKUP_FILE"
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                show_help
                ;;
        esac
    done

    check_requirements
    get_running_vms
    get_all_vms
    parse_hosts_file

    detect_conflicts
    determine_changes

    if [ "$DRY_RUN" == true ]; then
        show_dry_run
        exit 0
    fi

    if [ ${#add_entry[@]} -eq 0 ] && [ ${#removed_entry[@]} -eq 0 ]; then
        echo "KVM VMs /etc/hosts is up to date."
        echo "No changes needed."
        exit 0
    fi

    create_backup
    apply_changes
    show_summary
}

main "$@"

#!/bin/bash

# Script to list IP addresses of KVM virtual machines using ARP leases
# Output format: VMNAME    IP_ADDRESS    MAC_ADDRESS    INTERFACE

# --- Configuration ---
LEASES_FILE="/var/lib/arpalert/arpalert.leases"

# --- Main Logic ---

# Check if the leases file exists and is readable
if [[ ! -r "$LEASES_FILE" ]]; then
  echo "Error: Leases file not found or not readable at $LEASES_FILE" >&2
  exit 1
fi

# Create an associative array to hold MAC-to-IP mappings.
declare -A leases_map

# Read the ARP lease file efficiently without forking external commands in the loop.
# Format: MAC IP INTERFACE TIMESTAMP SEQUENCE
# We only need the first two fields (mac, ip).
while read -r mac ip _; do
  # Use built-in bash string manipulation for lowercasing. It's much faster.
  leases_map[${mac,,}]=$ip
done < "$LEASES_FILE"

# Use the --name flag for machine-readable output and to handle VM names with spaces.
# Process substitution <() is generally safer than for-in loops with command substitution.
while read -r vmname; do
  # Skip empty lines that might be returned for non-existent domains.
  [[ -z "$vmname" ]] && continue

  # Use `virsh domstate` for a direct, reliable check of the VM's state.
  if [[ "$(virsh domstate "$vmname")" == "running" ]]; then
    # Get interfaces, skipping the header and footer lines.
    # The `read` command here parses the line directly into variables.
    virsh domiflist "$vmname" | tail -n +3 | head -n -1 | while read -r iface type network model mac state; do
      # Skip interfaces without a MAC address
      [[ -z "$mac" ]] && continue

      # Use bash parameter expansion for lowercasing the MAC address.
      mac_lower=${mac,,}

      # Check if the lowercase MAC address is a key in our map.
      ip=${leases_map[$mac_lower]}

      if [[ -n "$ip" ]]; then
        # Output in consistent format: VMNAME IP MAC INTERFACE
        printf "%-20s %-15s %-17s %s\n" "$vmname" "$ip" "$mac" "$iface"
      fi
    done
  fi
done < <(virsh list --all --name)

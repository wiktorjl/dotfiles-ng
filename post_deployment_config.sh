#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$BASE_DIR/lib/distro.sh"

# Reject any hostname/domain that isn't valid RFC 1123 syntax. Without this,
# a pasted value containing a newline silently appends arbitrary lines to
# /etc/hosts via `sudo tee -a` (e.g. an attacker-controlled `1.2.3.4
# github.com`), and a leading `-` could turn into a `hostnamectl set-hostname
# --evil` flag injection.
validate_hostname_label() {
    local kind="$1" value="$2"
    if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]]; then
        echo "Error: $kind '$value' is not a valid RFC 1123 label." >&2
        echo "  Allowed: alnum and '-'; 1-63 chars; must start with alnum." >&2
        exit 1
    fi
}
validate_domain_name() {
    local value="$1"
    if [[ ! "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]] \
       || [ "${#value}" -gt 253 ]; then
        echo "Error: domain '$value' is not a valid RFC 1123 domain name." >&2
        exit 1
    fi
}

# is_container is sourced from lib/distro.sh

# Set hostname with fallback for containers
set_hostname() {
    local hostname="$1"
    
    if is_container; then
        echo "Container environment detected. Using fallback hostname methods..."
        
        # Method 1: Direct hostname command
        if command -v hostname >/dev/null 2>&1; then
            echo "Setting hostname using hostname command..."
            hostname "$hostname" 2>/dev/null || echo "Warning: Could not set runtime hostname"
        fi
        
        # Method 2: Update /etc/hostname
        echo "Updating /etc/hostname..."
        echo "$hostname" | sudo tee /etc/hostname >/dev/null
        
        # Method 3: Update /etc/hosts
        echo "Updating /etc/hosts..."
        sudo sed -i "/127.0.1.1/d" /etc/hosts 2>/dev/null || true
        echo "127.0.1.1    $hostname" | sudo tee -a /etc/hosts >/dev/null
        
        echo "Hostname set to $hostname (container mode)"
    else
        echo "Standard environment detected. Using systemd hostnamectl..."
        sudo hostnamectl set-hostname "$hostname"
        echo "Hostname set to $hostname (systemd mode)"
    fi
}

# Check and start SSH service with fallback
start_ssh_service() {
    if is_container; then
        echo "Container environment detected. Using fallback SSH methods..."
        
        # Try to start SSH daemon directly
        if command -v sshd >/dev/null 2>&1; then
            echo "Starting SSH daemon directly..."
            sudo /usr/sbin/sshd -D &
            echo "SSH daemon started (container mode)"
        elif [ -f /etc/init.d/ssh ]; then
            echo "Starting SSH using init script..."
            sudo /etc/init.d/ssh start
        else
            echo "Warning: SSH daemon not found or cannot be started in container"
            return 1
        fi
    else
        echo "Standard environment detected. Using systemctl..."
        sudo systemctl start ssh
        return $?
    fi
}

# Check if SSH service is running with fallback
is_ssh_running() {
    if is_container; then
        # Check if SSH process is running
        pgrep sshd >/dev/null 2>&1
    else
        systemctl is-active --quiet ssh
    fi
}

# Enable SSH service with fallback
enable_ssh_service() {
    if is_container; then
        echo "Container environment: SSH auto-start not applicable"
        echo "Note: In containers, SSH typically needs to be started manually or via init process"
        return 0
    else
        echo "Standard environment detected. Enabling SSH with systemctl..."
        sudo systemctl enable ssh
        return $?
    fi
}

# Check if SSH service is enabled with fallback
is_ssh_enabled() {
    if is_container; then
        # In containers, we can't really "enable" services in the traditional sense
        echo "Container environment: SSH enable status not applicable"
        return 0
    else
        systemctl is-enabled --quiet ssh
    fi
}

# Ask for host name
read -r -p "Enter the host name: " HOST_NAME
validate_hostname_label "hostname" "$HOST_NAME"
# Set the hostname using container-aware method
echo "Setting hostname to $HOST_NAME..."
set_hostname "$HOST_NAME"

# Ask if domain name should be set
read -r -p "Do you want to set a domain name? (y/n): " SET_DOMAIN
if [[ "$SET_DOMAIN" == "y" || "$SET_DOMAIN" == "Y" ]]; then
    read -r -p "Enter the domain name: " DOMAIN_NAME
    validate_domain_name "$DOMAIN_NAME"
    echo "Setting domain name to $DOMAIN_NAME..."
    set_hostname "$HOST_NAME.$DOMAIN_NAME"
else
    echo "Domain name not set."
fi

# Check group memberships. Groups are split into two tiers:
#   * standard groups (sudo/wheel/adm/users) — added automatically
#   * privileged-equivalent groups (docker/libvirt/kvm) — root-equivalent
#     locally (e.g. `docker run --privileged -v /:/mnt` trivially escalates
#     to root), so they require an explicit opt-in.
check_and_add_group() {
    local group_name="$1"
    if getent group "$group_name" > /dev/null; then
        if ! groups "$USER" | grep -q "\b$group_name\b"; then
            echo "Adding user $USER to group $group_name..."
            sudo usermod -aG "$group_name" "$USER"
        else
            echo "User $USER is already in group $group_name."
        fi
    else
        echo "Group $group_name does not exist."
    fi
}

standard_groups=("sudo" "wheel" "adm" "users")
privileged_groups=("docker" "libvirt" "kvm")

for group in "${standard_groups[@]}"; do
    check_and_add_group "$group"
done

if [ -t 0 ]; then
    echo
    echo "The following groups grant local root-equivalent capability:"
    for g in "${privileged_groups[@]}"; do echo "  - $g"; done
    echo "Membership means any code running as $USER (including a compromised"
    echo "shell or extension) can trivially become root."
    read -r -p "Add $USER to these groups anyway? (y/N): " ADD_PRIV_GROUPS
    if [[ "$ADD_PRIV_GROUPS" == "y" || "$ADD_PRIV_GROUPS" == "Y" ]]; then
        for group in "${privileged_groups[@]}"; do
            check_and_add_group "$group"
        done
    else
        echo "Skipping privileged group additions. Use 'sudo' explicitly for"
        echo "docker/libvirt/virsh commands, or rerun this script to opt in."
    fi
else
    echo "Non-interactive run: skipping privileged group additions (docker/libvirt/kvm)."
    echo "Rerun this script interactively if you want to opt in."
fi
# Ask for a reboot (container-aware)
if is_container; then
    echo "Container environment detected. Reboot not applicable."
    echo "Note: In containers, restart the container to apply hostname changes."
    echo "Group membership changes will take effect on next shell login."
else
    read -r -p "Do you want to reboot the system now? (y/n): " REBOOT_NOW
    if [[ "$REBOOT_NOW" == "y" || "$REBOOT_NOW" == "Y" ]]; then
        echo "Rebooting the system..."
        sudo reboot
    else
        echo "Reboot skipped. Please reboot the system later to apply changes."
    fi
fi
# End of script
echo "Configuration complete. Please check the changes and reboot if necessary."

# Ask if SSH should be configured
read -r -p "Do you want to configure SSH Server? (y/n): " CONFIGURE_SSH_SERVER

if [[ "$CONFIGURE_SSH_SERVER" == "y" || "$CONFIGURE_SSH_SERVER" == "Y" ]]; then
    # Check if SSH service is running
    if is_ssh_running; then
        echo "SSH service is running."
    else
        echo "SSH service is not running. Starting SSH service..."
        if start_ssh_service; then
            if is_ssh_running; then
                echo "SSH service started successfully."
            else
                echo "SSH service start command completed, but status unclear."
            fi
        else
            echo "Failed to start SSH service. Please check the logs."
        fi
    fi

    # Check if SSH service is enabled to start on boot
    if ! is_container; then
        if is_ssh_enabled; then
            echo "SSH service is enabled to start on boot."
        else
            echo "SSH service is not enabled to start on boot. Enabling SSH service..."
            if enable_ssh_service; then
                if is_ssh_enabled; then
                    echo "SSH service enabled successfully."
                else
                    echo "Failed to enable SSH service. Please check the logs."
                fi
            else
                echo "Failed to enable SSH service."
            fi
        fi
    fi 
else
    echo "Skipping SSH Server configuration."
fi
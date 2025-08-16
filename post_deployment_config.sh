#!/bin/bash

# Detect if running in Docker/container environment
is_container() {
    # Check for Docker environment
    if [ -f /.dockerenv ]; then
        return 0
    fi
    
    # Check for container environment variables
    if [ -n "$container" ] || [ -n "$DOCKER_CONTAINER" ]; then
        return 0
    fi
    
    # Check if systemd is available and running
    if ! command -v systemctl >/dev/null 2>&1; then
        return 0
    fi
    
    if ! systemctl is-system-running >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

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
read -p "Enter the host name: " HOST_NAME
# Set the hostname using container-aware method
echo "Setting hostname to $HOST_NAME..."
set_hostname "$HOST_NAME"

# Ask if domain name should be set
read -p "Do you want to set a domain name? (y/n): " SET_DOMAIN
if [[ "$SET_DOMAIN" == "y" || "$SET_DOMAIN" == "Y" ]]; then
    read -p "Enter the domain name: " DOMAIN_NAME
    echo "Setting domain name to $DOMAIN_NAME..."
    set_hostname "$HOST_NAME.$DOMAIN_NAME"
else
    echo "Domain name not set."
fi

# Check if the user is in the right groups (docker, libvirt, kvm, sudo, wheel, adm, users, etc.) and if a group exists, add the user to it
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
# List of groups to check
groups_to_check=("docker" "libvirt" "kvm" "sudo" "wheel" "adm" "users")
# Check and add user to each group
for group in "${groups_to_check[@]}"; do
    check_and_add_group "$group"
done
# Ask for a reboot (container-aware)
if is_container; then
    echo "Container environment detected. Reboot not applicable."
    echo "Note: In containers, restart the container to apply hostname changes."
    echo "Group membership changes will take effect on next shell login."
else
    read -p "Do you want to reboot the system now? (y/n): " REBOOT_NOW
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
read -p "Do you want to configure SSH Server? (y/n): " CONFIGURE_SSH_SERVER

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
#!/bin/bash


# Ask for host name
read -p "Enter the host name: " HOST_NAME
# Set the hostname
echo "Setting hostname to $HOST_NAME..."
sudo hostnamectl set-hostname "$HOST_NAME"

# Ask if domain name should be set
read -p "Do you want to set a domain name? (y/n): " SET_DOMAIN
if [[ "$SET_DOMAIN" == "y" || "$SET_DOMAIN" == "Y" ]]; then
    read -p "Enter the domain name: " DOMAIN_NAME
    echo "Setting domain name to $DOMAIN_NAME..."
    sudo hostnamectl set-hostname "$HOST_NAME.$DOMAIN_NAME"
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
# Ask for a reboot
read -p "Do you want to reboot the system now? (y/n): " REBOOT_NOW
if [[ "$REBOOT_NOW" == "y" || "$REBOOT_NOW" == "Y" ]]; then
    echo "Rebooting the system..."
    sudo reboot
else
    echo "Reboot skipped. Please reboot the system later to apply changes."
fi
# End of script
echo "Configuration complete. Please check the changes and reboot if necessary."

# Ask if SSH should be configured
read -p "Do you want to configure SSH Server? (y/n): " CONFIGURE_SSH_SERVER

if [[ "$CONFIGURE_SSH_SERVER" == "y" || "$CONFIGURE_SSH_SERVER" == "Y" ]]; then
    # Check if SSH service is running
    if systemctl is-active --quiet ssh; then
        echo "SSH service is running."
    else
        echo "SSH service is not running. Starting SSH service..."
        sudo systemctl start ssh
        if systemctl is-active --quiet ssh; then
            echo "SSH service started successfully."
        else
            echo "Failed to start SSH service. Please check the logs."
        fi
    fi

    # Check if SSH service is enabled to start on boot
    if systemctl is-enabled --quiet ssh; then
        echo "SSH service is enabled to start on boot."
    else
        echo "SSH service is not enabled to start on boot. Enabling SSH service..."
        sudo systemctl enable ssh
        if systemctl is-enabled --quiet ssh; then
            echo "SSH service enabled successfully."
        else
            echo "Failed to enable SSH service. Please check the logs."
        fi
    fi 
else
    echo "Skipping SSH Server configuration."
fi
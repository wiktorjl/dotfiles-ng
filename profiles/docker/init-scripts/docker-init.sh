#!/bin/bash

echo "-----------------------------------------------------"
echo "Attempting to install Docker..."
echo "-----------------------------------------------------"

# Check if Docker repository is already configured
if [ -f /etc/apt/sources.list.d/docker.list ] && [ -f /etc/apt/keyrings/docker.asc ] && grep -q "download.docker.com/linux/debian" /etc/apt/sources.list.d/docker.list; then
    echo "Docker repository already configured, skipping setup..."
else
    echo "Setting up Docker repository..."
    sudo mkdir -p /etc/apt/keyrings
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    echo "Docker repository setup completed successfully."
fi

sudo apt update
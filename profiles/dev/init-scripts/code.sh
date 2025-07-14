#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Visual Studio Code (VS Code)..."
echo "-----------------------------------------------------"

echo "1. Downloading Microsoft GPG key..."
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o microsoft.gpg
if [ $? -ne 0 ]; then
    echo "Error: Failed to download or dearmor Microsoft GPG key."
    rm -f microsoft.gpg # Clean up
    return 1
fi

echo "2. Installing Microsoft GPG key..."
sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/keyrings/microsoft-archive-keyring.gpg
if [ $? -ne 0 ]; then
    echo "Error: Failed to install Microsoft GPG key."
    rm -f microsoft.gpg # Clean up
    return 1
fi
rm -f microsoft.gpg # Clean up the temporary gpg file

echo "3. Adding VS Code repository..."
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
if [ $? -ne 0 ]; then
    echo "Error: Failed to add VS Code repository."
    # Consider removing the key and list file if repo add fails
    sudo rm -f /etc/apt/keyrings/microsoft-archive-keyring.gpg /etc/apt/sources.list.d/vscode.list
    return 1
fi

echo "4. Updating package lists (after adding VS Code repo)..."
sudo apt update
if [ $? -ne 0 ]; then
    echo "Warning: Failed to update package lists after adding VS Code repo. Installation might fail."
    # Don't necessarily exit, let apt install try
fi

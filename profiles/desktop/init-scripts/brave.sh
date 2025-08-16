#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Brave Browser..."
echo "-----------------------------------------------------"

# Install dependencies
sudo apt install -y apt-transport-https curl

# Check if Brave repository is already added
if [ ! -f /etc/apt/sources.list.d/brave-browser-release.list ] || ! grep -q "brave-browser-apt-release.s3.brave.com" /etc/apt/sources.list.d/brave-browser-release.list; then
    echo "Adding Brave repository..."
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
else
    echo "Brave repository already exists, skipping..."
fi

echo "Updating package lists after adding Brave repository..."
sudo apt update

echo "Brave repository setup completed successfully."
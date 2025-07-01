#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Brave Browser..."
echo "-----------------------------------------------------"

# Check if Brave is already installed
if command -v brave &> /dev/null; then
    echo "Brave Browser is already installed. Skipping installation."
    return
fi

# Install dependencies
sudo apt install -y apt-transport-https curl

sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list

sudo apt update
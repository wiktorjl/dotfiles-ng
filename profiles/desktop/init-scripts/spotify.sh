#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Spotify Desktop..."
echo "-----------------------------------------------------"

# Check if Spotify repository is already added
if [ ! -f /etc/apt/sources.list.d/spotify.list ] || ! grep -q "repository.spotify.com" /etc/apt/sources.list.d/spotify.list; then
    echo "Adding Spotify repository..."
    curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
else
    echo "Spotify repository already exists, skipping..."
fi

echo "Updating package lists after adding Spotify repository..."
sudo apt update

echo "Spotify repository setup completed successfully."

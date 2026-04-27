#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Spotify Desktop..."
echo "-----------------------------------------------------"

# Spotify rotates this signing key roughly yearly. When apt starts complaining
# the repo isn't signed, look up the current key id from the live InRelease
# signature and bump SPOTIFY_KEY_URL — the URL pattern uses the 64-bit short
# key id, NOT the 96-bit long form:
#   gpg --verify <(curl -s https://repository.spotify.com/dists/stable/InRelease)
#   # → "using RSA key <fingerprint>" — take the last 16 hex chars
#   curl -I https://download.spotify.com/debian/pubkey_<SHORT16>.gpg  # expect 200
SPOTIFY_KEY_URL="https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.gpg"

# Always refresh the key — handles first install AND key rotations on re-runs.
echo "Installing Spotify signing key..."
curl -sS "$SPOTIFY_KEY_URL" | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg

if [ ! -f /etc/apt/sources.list.d/spotify.list ] || ! grep -q "repository.spotify.com" /etc/apt/sources.list.d/spotify.list; then
    echo "Adding Spotify repository..."
    echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
else
    echo "Spotify repository already exists, skipping..."
fi

echo "Updating package lists after adding Spotify repository..."
sudo apt update

echo "Spotify repository setup completed successfully."

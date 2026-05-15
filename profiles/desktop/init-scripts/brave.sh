#!/bin/bash
set -euo pipefail

echo "-----------------------------------------------------"
echo "Attempting to install Brave Browser..."
echo "-----------------------------------------------------"

# Brave's published apt key fingerprint. From
# https://brave-browser.readthedocs.io/en/latest/installing-brave.html — bump
# when Brave rotates.
BRAVE_KEY_FINGERPRINT="${BRAVE_KEY_FINGERPRINT:-F633B4E891C40BB18A29F0BD11FA56D3CFB7C97E}"

# Install dependencies
sudo apt install -y apt-transport-https curl gpg

# Check if Brave repository is already added
if [ ! -f /etc/apt/sources.list.d/brave-browser-release.list ] \
    || ! grep -q "brave-browser-apt-release.s3.brave.com" /etc/apt/sources.list.d/brave-browser-release.list; then
    echo "Adding Brave repository..."

    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    if ! curl -fsSL -o "$workdir/brave.gpg" \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; then
        echo "Error: failed to fetch Brave signing key." >&2
        exit 1
    fi

    actual_fpr=$(gpg --homedir "$workdir/gpg" --quiet --no-default-keyring --keyring "$workdir/scratch.gpg" \
        --batch --with-colons --import-options show-only --import "$workdir/brave.gpg" 2>/dev/null \
        | awk -F: '/^fpr:/ {print $10; exit}')
    expected="${BRAVE_KEY_FINGERPRINT// /}"
    if [ "${actual_fpr^^}" != "${expected^^}" ]; then
        echo "ERROR: Brave key fingerprint mismatch." >&2
        echo "  expected: ${expected^^}" >&2
        echo "  actual:   ${actual_fpr^^}" >&2
        exit 1
    fi

    sudo install -o root -g root -m 0644 "$workdir/brave.gpg" /usr/share/keyrings/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
else
    echo "Brave repository already exists, skipping..."
fi

echo "Updating package lists after adding Brave repository..."
sudo apt update

echo "Brave repository setup completed successfully."

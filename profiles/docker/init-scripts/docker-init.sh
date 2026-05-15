#!/bin/bash
set -euo pipefail

echo "-----------------------------------------------------"
echo "Attempting to install Docker..."
echo "-----------------------------------------------------"

# Fingerprint of the Docker, Inc. signing key. From
# https://docs.docker.com/engine/install/debian/ — verify when you bump.
DOCKER_KEY_FINGERPRINT="${DOCKER_KEY_FINGERPRINT:-9DC858229FC7DD38854AE2D88D81803C0EBFCD88}"

# Check if Docker repository is already configured
if [ -f /etc/apt/sources.list.d/docker.list ] \
    && [ -f /etc/apt/keyrings/docker.gpg ] \
    && grep -q "download.docker.com/linux/debian" /etc/apt/sources.list.d/docker.list; then
    echo "Docker repository already configured, skipping setup..."
else
    echo "Setting up Docker repository..."
    sudo install -m 0755 -d /etc/apt/keyrings

    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    if ! curl -fsSL https://download.docker.com/linux/debian/gpg -o "$workdir/docker.asc"; then
        echo "Error: failed to fetch Docker signing key." >&2
        exit 1
    fi

    # Verify the fingerprint of the downloaded key BEFORE trusting it.
    actual_fpr=$(gpg --homedir "$workdir/gpg" --quiet --no-default-keyring --keyring "$workdir/scratch.gpg" \
        --batch --with-colons --import-options show-only --import "$workdir/docker.asc" 2>/dev/null \
        | awk -F: '/^fpr:/ {print $10; exit}')
    expected="${DOCKER_KEY_FINGERPRINT// /}"
    if [ "${actual_fpr^^}" != "${expected^^}" ]; then
        echo "ERROR: Docker key fingerprint mismatch." >&2
        echo "  expected: ${expected^^}" >&2
        echo "  actual:   ${actual_fpr^^}" >&2
        exit 1
    fi

    # Install as a dearmored .gpg (more space-efficient and consistent with
    # other keyrings in this repo).
    gpg --dearmor < "$workdir/docker.asc" > "$workdir/docker.gpg"
    sudo install -o root -g root -m 0644 "$workdir/docker.gpg" /etc/apt/keyrings/docker.gpg

    # Remove the legacy .asc path if a prior version of this script wrote it.
    sudo rm -f /etc/apt/keyrings/docker.asc

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Docker repository setup completed successfully."
fi

sudo apt update

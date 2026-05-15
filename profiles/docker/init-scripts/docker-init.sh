#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/distro.sh"

echo "-----------------------------------------------------"
echo "Attempting to install Docker..."
echo "-----------------------------------------------------"

# Fingerprint of the Docker, Inc. signing key. From
# https://docs.docker.com/engine/install/debian/ (and the matching Ubuntu page).
# Docker publishes the same key for both repos; verify when you bump.
DOCKER_KEY_FINGERPRINT="${DOCKER_KEY_FINGERPRINT:-9DC858229FC7DD38854AE2D88D81803C0EBFCD88}"

# Docker hosts per-distro repos under download.docker.com/linux/<distro>. The
# path must match the running distro — installing the Debian repo on Ubuntu
# (or vice versa) produces 404s on the next apt-get update.
case "$(os_id)" in
    debian) DOCKER_REPO_DISTRO=debian ;;
    ubuntu) DOCKER_REPO_DISTRO=ubuntu ;;
    *)
        echo "ERROR: docker-init.sh does not know how to install Docker for '$(os_id)'." >&2
        echo "  Supported: debian, ubuntu. Add a case here when extending." >&2
        exit 1
        ;;
esac
DOCKER_REPO_URL="https://download.docker.com/linux/${DOCKER_REPO_DISTRO}"

# Skip setup if the repo is already configured for *this* distro.
if [ -f /etc/apt/sources.list.d/docker.list ] \
    && [ -f /etc/apt/keyrings/docker.gpg ] \
    && grep -q "download.docker.com/linux/${DOCKER_REPO_DISTRO}" /etc/apt/sources.list.d/docker.list; then
    echo "Docker repository already configured, skipping setup..."
else
    echo "Setting up Docker repository for ${DOCKER_REPO_DISTRO}..."
    sudo install -m 0755 -d /etc/apt/keyrings

    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    if ! curl -fsSL "${DOCKER_REPO_URL}/gpg" -o "$workdir/docker.asc"; then
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
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_REPO_URL} \
        $(os_codename) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Docker repository setup completed successfully."
fi

sudo apt-get update -qq

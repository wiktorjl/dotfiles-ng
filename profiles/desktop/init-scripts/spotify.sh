#!/bin/bash
set -euo pipefail

echo "-----------------------------------------------------"
echo "Attempting to install Spotify Desktop..."
echo "-----------------------------------------------------"

# Pinning + scoping changes:
#   * the key is now scoped via `signed-by=` in the sources.list.d line,
#     instead of dropped into /etc/apt/trusted.gpg.d/ (which trusts the key
#     globally for *every* configured apt repo);
#   * we verify the downloaded key's fingerprint before installing it, so a
#     CDN/MITM swap can't silently pivot.
#
# To bump the URL when Spotify rotates the key, find the new short key id:
#   gpg --verify <(curl -s https://repository.spotify.com/dists/stable/InRelease)
# Then update SPOTIFY_KEY_URL and SPOTIFY_KEY_FINGERPRINT to match.

SPOTIFY_KEY_URL="${SPOTIFY_KEY_URL:-}"
SPOTIFY_KEY_FINGERPRINT="${SPOTIFY_KEY_FINGERPRINT:-}"

if [ -z "$SPOTIFY_KEY_URL" ] || [ -z "$SPOTIFY_KEY_FINGERPRINT" ]; then
    cat >&2 <<'EOF'
ERROR: Spotify signing-key pin is not configured.

  export SPOTIFY_KEY_URL="https://download.spotify.com/debian/pubkey_<SHORT16>.gpg"
  export SPOTIFY_KEY_FINGERPRINT="<40-char hex GPG fingerprint, no spaces>"

Find the fingerprint with:
  gpg --verify <(curl -s https://repository.spotify.com/dists/stable/InRelease)
  # → "using RSA key <fingerprint>"
EOF
    exit 1
fi

# Strip any spaces a user might have pasted in.
SPOTIFY_KEY_FINGERPRINT="${SPOTIFY_KEY_FINGERPRINT// /}"
if ! [[ "$SPOTIFY_KEY_FINGERPRINT" =~ ^[0-9A-Fa-f]{40}$ ]]; then
    echo "ERROR: SPOTIFY_KEY_FINGERPRINT must be a 40-char hex GPG fingerprint." >&2
    exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
keyring_dir="/etc/apt/keyrings"

echo "Downloading Spotify signing key..."
if ! curl --fail --location --silent --show-error -o "$workdir/spotify.key" "$SPOTIFY_KEY_URL"; then
    echo "ERROR: failed to fetch $SPOTIFY_KEY_URL" >&2
    exit 1
fi

echo "Verifying fingerprint..."
# `gpg --show-keys --with-colons` parses the file without importing it.
actual_fpr=$(gpg --homedir "$workdir/gpg" --quiet --no-default-keyring --keyring "$workdir/scratch.gpg" \
    --batch --with-colons --import-options show-only --import "$workdir/spotify.key" 2>/dev/null \
    | awk -F: '/^fpr:/ {print $10; exit}')
if [ "${actual_fpr^^}" != "${SPOTIFY_KEY_FINGERPRINT^^}" ]; then
    echo "ERROR: key fingerprint mismatch." >&2
    echo "  expected: ${SPOTIFY_KEY_FINGERPRINT^^}" >&2
    echo "  actual:   ${actual_fpr^^}" >&2
    exit 1
fi

echo "Installing key under $keyring_dir/spotify.gpg..."
gpg --dearmor < "$workdir/spotify.key" > "$workdir/spotify.gpg"
sudo install -o root -g root -m 0644 -D "$workdir/spotify.gpg" "$keyring_dir/spotify.gpg"

# Drop any old globally-trusted copy left over from prior versions of this
# script so apt no longer trusts the Spotify key for unrelated repositories.
if [ -e /etc/apt/trusted.gpg.d/spotify.gpg ]; then
    echo "Removing legacy /etc/apt/trusted.gpg.d/spotify.gpg (global trust)..."
    sudo rm -f /etc/apt/trusted.gpg.d/spotify.gpg
fi

if [ ! -f /etc/apt/sources.list.d/spotify.list ] || ! grep -q "signed-by=$keyring_dir/spotify.gpg" /etc/apt/sources.list.d/spotify.list; then
    echo "Writing /etc/apt/sources.list.d/spotify.list..."
    echo "deb [signed-by=$keyring_dir/spotify.gpg] https://repository.spotify.com stable non-free" \
        | sudo tee /etc/apt/sources.list.d/spotify.list >/dev/null
else
    echo "Spotify repository already scoped to keyring, skipping..."
fi

echo "Updating package lists after adding Spotify repository..."
sudo apt update

echo "Spotify repository setup completed successfully."

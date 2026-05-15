#!/bin/bash
set -euo pipefail

# Install JetBrainsMono Nerd Font from a pinned release with SHA-256
# verification.
#
# Previously this downloaded releases/latest/download/JetBrainsMono.tar.xz
# and extracted it with no integrity check. Fonts are parsed by FreeType /
# fontconfig / the kernel framebuffer console, all of which have non-trivial
# CVE histories, so an upstream release-asset swap can reach exploitable
# parsers as soon as fc-cache runs.
#
# To bump: pick a tag at https://github.com/ryanoasis/nerd-fonts/releases,
# fetch the JetBrainsMono.tar.xz, run `sha256sum`, update both values.

NERDFONT_VERSION="${NERDFONT_VERSION:-}"
NERDFONT_SHA256="${NERDFONT_SHA256:-}"

if [ -z "$NERDFONT_VERSION" ] || [ -z "$NERDFONT_SHA256" ]; then
    cat >&2 <<'EOF'
ERROR: Nerd Fonts pin is not configured.

  export NERDFONT_VERSION=<tag, e.g. v3.2.1>
  export NERDFONT_SHA256=<sha256 of JetBrainsMono.tar.xz at that tag>

Source: https://github.com/ryanoasis/nerd-fonts/releases

Skipping Nerd Fonts installation.
EOF
    exit 1
fi

if ! [[ "$NERDFONT_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: NERDFONT_SHA256 must be a 64-char hex SHA-256." >&2
    exit 1
fi

echo "-----------------------------------------------------"
echo "Installing JetBrainsMono Nerd Font $NERDFONT_VERSION"
echo "-----------------------------------------------------"

fonts_dir="$HOME/.local/share/fonts"
mkdir -p "$fonts_dir"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
archive="$workdir/JetBrainsMono.tar.xz"

url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERDFONT_VERSION}/JetBrainsMono.tar.xz"
if ! curl --fail --location --silent --show-error --output "$archive" "$url"; then
    echo "ERROR: failed to download $url" >&2
    exit 1
fi

actual_sha=$(sha256sum "$archive" | awk '{print $1}')
if [ "$actual_sha" != "$NERDFONT_SHA256" ]; then
    echo "ERROR: archive checksum mismatch." >&2
    echo "  expected: $NERDFONT_SHA256" >&2
    echo "  actual:   $actual_sha" >&2
    exit 1
fi

echo "Extracting fonts..."
tar -xf "$archive" -C "$fonts_dir"
echo "Refreshing fonts cache..."
fc-cache -f "$fonts_dir"
echo "Done."

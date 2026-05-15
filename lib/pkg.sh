# shellcheck shell=bash
# Package-manager abstraction.
#
# Today this only knows apt/dpkg (Debian + Ubuntu and derivatives). It exists
# so the rest of the codebase doesn't sprinkle apt-get/apt-cache/dpkg calls
# everywhere — when a non-apt distro is added later, this is the only file
# that needs new branches.
#
# Functions (all return the command's exit code):
#   pkg_update                 — refresh package index
#   pkg_install <pkg>...       — install one or more packages
#   pkg_installed <pkg>        — 0 if installed, non-zero otherwise
#   pkg_available <pkg>        — 0 if installable from a configured repo
#   pkg_install_one <pkg>      — install a single package (fallback path)

if [ -n "${_LIB_PKG_SOURCED:-}" ]; then return 0; fi
_LIB_PKG_SOURCED=1

_pkg_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$_pkg_dir/distro.sh"

if ! is_debian_like; then
    echo "lib/pkg.sh: unsupported distro '$(os_id)'. Only Debian-family is supported today." >&2
    return 1 2>/dev/null || exit 1
fi

# Suppress debconf prompts during package installs. Set here so callers don't
# have to remember; preserved across sudo via the env list below.
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
_PKG_SUDO_ENV=(--preserve-env=DEBIAN_FRONTEND,DEBCONF_NONINTERACTIVE_SEEN)

pkg_update() {
    sudo "${_PKG_SUDO_ENV[@]}" apt-get update -qq
}

pkg_install() {
    sudo "${_PKG_SUDO_ENV[@]}" apt-get install -y -qq --no-install-recommends "$@"
}

pkg_install_one() {
    sudo "${_PKG_SUDO_ENV[@]}" apt-get install -y -qq "$1"
}

pkg_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

pkg_available() {
    apt-cache show "$1" >/dev/null 2>&1
}

# Partition a list of packages into available / unavailable via a single
# apt-cache call. Sets PKG_AVAILABLE and PKG_UNAVAILABLE as global arrays.
# Much faster than calling pkg_available in a loop (one fork instead of N).
pkg_partition_available() {
    PKG_AVAILABLE=()
    PKG_UNAVAILABLE=()
    [ $# -eq 0 ] && return 0

    declare -A _pkg_known=()
    local name
    while IFS= read -r name; do
        _pkg_known["$name"]=1
    done < <(apt-cache pkgnames 2>/dev/null)

    local pkg
    for pkg in "$@"; do
        if [ -n "${_pkg_known[$pkg]:-}" ]; then
            PKG_AVAILABLE+=("$pkg")
        else
            PKG_UNAVAILABLE+=("$pkg")
        fi
    done
}

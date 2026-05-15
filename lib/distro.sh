# shellcheck shell=bash
# Distro + environment detection helpers.
#
# Functions:
#   os_id           — lowercase distro ID from /etc/os-release (debian, ubuntu, ...)
#   os_id_like      — space-separated ID_LIKE value (e.g. "debian")
#   os_codename     — release codename (bookworm, jammy, ...)
#   is_debian_like  — 0 if Debian or Debian-derived (Ubuntu, Mint, ...)
#   is_container    — 0 if running inside a container / no functional systemd

if [ -n "${_LIB_DISTRO_SOURCED:-}" ]; then return 0; fi
_LIB_DISTRO_SOURCED=1

_distro_load() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        _DISTRO_ID="${ID:-unknown}"
        _DISTRO_ID_LIKE="${ID_LIKE:-}"
        _DISTRO_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"
    else
        _DISTRO_ID="unknown"
        _DISTRO_ID_LIKE=""
        _DISTRO_CODENAME="unknown"
    fi
}
_distro_load

os_id() { printf '%s\n' "$_DISTRO_ID"; }
os_id_like() { printf '%s\n' "$_DISTRO_ID_LIKE"; }
os_codename() { printf '%s\n' "$_DISTRO_CODENAME"; }

is_debian_like() {
    case "$_DISTRO_ID" in
        debian|ubuntu|linuxmint|pop|elementary|kali|raspbian) return 0 ;;
    esac
    case " $_DISTRO_ID_LIKE " in
        *" debian "*|*" ubuntu "*) return 0 ;;
    esac
    return 1
}

is_container() {
    [ -f /.dockerenv ] && return 0
    if [ -n "${container:-}" ] || [ -n "${DOCKER_CONTAINER:-}" ]; then
        return 0
    fi
    command -v systemctl >/dev/null 2>&1 || return 0
    systemctl is-system-running >/dev/null 2>&1 || return 0
    return 1
}

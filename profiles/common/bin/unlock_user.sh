#!/bin/sh
set -u

if [ "$#" -lt 1 ] || [ -z "${1:-}" ]; then
    echo "Must provide username...." >&2
    exit 1
fi

user="$1"

# Validate against POSIX-portable user name (3.437 of IEEE 1003.1-2017).
# Without this, a value like "alice --dir /tmp/attacker" field-splits into
# extra faillock arguments under root.
case "$user" in
    -*) echo "Refusing username starting with '-': $user" >&2; exit 1 ;;
esac
if ! printf '%s' "$user" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}\$?$'; then
    echo "Invalid username (POSIX): $user" >&2
    exit 1
fi

echo "Unlocking user $user"
sudo -- faillock --user "$user" --reset

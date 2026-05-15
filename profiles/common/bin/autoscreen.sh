#!/bin/bash
set -uo pipefail

# Use flock against a file in the user's runtime dir, not /tmp. The previous
# version used `/tmp/autosize.lock.$$` — a PID-suffixed lock in world-writable
# /tmp, with the trap registered AFTER the `touch`, so a crash between the two
# leaked the lock file forever. A predictable lockfile path in /tmp is also a
# symlink-attack primitive (touch follows symlinks).
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[ -d "$runtime_dir" ] || runtime_dir="$HOME/.cache"
mkdir -p "$runtime_dir"
LOCKFILE="$runtime_dir/autoscreen.lock"

exec 9>"$LOCKFILE"
if ! flock -n 9; then
    exit 0
fi
trap 'flock -u 9 2>/dev/null; rm -f "$LOCKFILE"' EXIT

xrandr --output Virtual-1 --auto

prev_output=""

echo "Starting display configuration monitor..."
echo "Press Ctrl+C to stop"

while true; do
    current_output=$(xrandr | grep "+" | grep "^ " || true)

    if [ "$current_output" != "$prev_output" ]; then
        if [ -n "$prev_output" ]; then
            echo "$(date): Display configuration changed!"
            echo "New configuration:"
            echo "$current_output"
            echo "---"
            xrandr --output Virtual-1 --auto
        fi
        prev_output="$current_output"
    fi

    sleep 1
done

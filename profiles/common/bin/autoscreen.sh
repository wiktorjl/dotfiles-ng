#!/bin/bash

LOCKFILE="/tmp/autosize.lock.$$"
if [ -f "$LOCKFILE" ]; then
	exit 1
fi

touch "$LOCKFILE"

xrandr --output Virtual-1 --auto

# Initialize previous output variable
prev_output=""

echo "Starting display configuration monitor..."
echo "Press Ctrl+C to stop"

while true; do
    # Get current display configuration
    current_output=$(xrandr | grep "+" | grep "^ ")
    
    # Check if output is different from previous
    if [ "$current_output" != "$prev_output" ]; then
        # Only print message if prev_output is not empty (skip first iteration)
        if [ -n "$prev_output" ]; then
            echo "$(date): Display configuration changed!"
            echo "New configuration:"
            echo "$current_output"
            echo "---"
            xrandr --output Virtual-1 --auto
        fi
        # Update previous output
        prev_output="$current_output"
    fi
    
    # Wait 1 second
    sleep 1
done

trap "rm -f $LOCKFILE" EXIT

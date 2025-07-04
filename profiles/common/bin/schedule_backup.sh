#!/bin/bash

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <schedule> <script_path> <log_directory>"
    echo "Example: $0 '0 2 * * *' /path/to/script.sh /home/user/logs"
    exit 1
fi

SCHEDULE="$1"
SCRIPT_PATH="$2"
LOG_DIR="$3"

if [ ! -x "$SCRIPT_PATH" ]; then
    echo "Error: Script $SCRIPT_PATH does not exist or is not executable"
    exit 1
fi

mkdir -p "$LOG_DIR"
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Could not create log directory $LOG_DIR"
    exit 1
fi

TMP_CRON=$(mktemp)

crontab -l > "$TMP_CRON" 2>/dev/null || true

if grep -q "$SCRIPT_PATH" "$TMP_CRON" 2>/dev/null; then
    echo "Warning: Entry for $SCRIPT_PATH already exists in crontab"
    rm "$TMP_CRON"
    exit 1
fi

echo "$SCHEDULE $SCRIPT_PATH >> $LOG_DIR/\$(date +\%Y\%m\%d_\%H\%M\%S).log 2>&1" >> "$TMP_CRON"

if crontab "$TMP_CRON"; then
    echo "Successfully added cron job"
    echo "Schedule: $SCHEDULE"
    echo "Script: $SCRIPT_PATH"
    echo "Logs will be stored in: $LOG_DIR"
else
    echo "Error: Failed to install crontab"
    rm "$TMP_CRON"
    exit 1
fi

rm "$TMP_CRON"
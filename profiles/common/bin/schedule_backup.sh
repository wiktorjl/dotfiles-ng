#!/bin/bash

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <schedule> <script_path> <log_directory>"
    echo "Example: $0 '0 2 * * *' /path/to/script.sh /home/user/logs"
    exit 1
fi

SCHEDULE="$1"
SCRIPT_PATH="$2"
LOG_DIR="$3"

# Validate inputs before they reach the crontab line.
#
# Cron expression: 5 whitespace-separated fields, each composed of
# digits/star/comma/dash/slash. This is intentionally a syntactic check —
# the cron daemon will still reject semantically wrong fields, but we want
# to refuse anything containing shell metacharacters or newlines first.
if [[ ! "$SCHEDULE" =~ ^[[:space:]]*[*0-9,/-]+([[:space:]]+[*0-9,/-]+){4}[[:space:]]*$ ]]; then
    echo "Error: schedule '$SCHEDULE' does not look like a 5-field cron expression." >&2
    echo "  Allowed per field: digits, '*', ',', '-', '/'" >&2
    exit 1
fi
# Script path and log dir: refuse anything containing characters that would
# need escaping in a crontab line.
case "$SCRIPT_PATH$LOG_DIR" in
    *[\'\"\`\$\;\&\|\<\>\\$'\n']*)
        echo "Error: script/log paths contain shell metacharacters." >&2
        exit 1 ;;
esac

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
trap 'rm -f "$TMP_CRON"' EXIT

crontab -l > "$TMP_CRON" 2>/dev/null || true

if grep -q "$SCRIPT_PATH" "$TMP_CRON" 2>/dev/null; then
    echo "Warning: Entry for $SCRIPT_PATH already exists in crontab"
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
    exit 1
fi
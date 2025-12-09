#!/bin/bash

SOURCE="/home/seed/EGG"
DEST="wiktor@10.10.10.137:/volume1/Data/HotStorage"
LOGFILE="/var/log/synology-rsync.log"
SSH_KEY="/home/seed/.ssh/synology_rsync_backup"  # 👈 your custom key

# Safety checks
if [ ! -f "$SSH_KEY" ]; then
    echo "$(date -Iseconds) - ERROR: SSH key not found: $SSH_KEY" >> "$LOGFILE"
    exit 1
fi

touch "$LOGFILE"
chown "$(whoami)" "$LOGFILE" 2>/dev/null || true

echo "$(date -Iseconds) - Starting rsync backup..." >> "$LOGFILE"

# Run rsync with custom SSH key
if rsync -aHAX --delete --numeric-ids \
   -e "ssh -i '$SSH_KEY' -o StrictHostKeyChecking=yes -o ConnectTimeout=30" \
   "$SOURCE" "$DEST" >> "$LOGFILE" 2>&1; then

    echo "$(date -Iseconds) - Backup completed successfully." >> "$LOGFILE"
    exit 0
else
    echo "$(date -Iseconds) - ERROR: Backup failed with exit code $?" >> "$LOGFILE"
    exit 1
fi

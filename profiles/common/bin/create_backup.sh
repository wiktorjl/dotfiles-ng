#!/bin/bash

CONFIG_FILE="$HOME/.qbkp/config"
DEFAULT_SOURCE_DIR="$HOME"
DEFAULT_BACKUP_DIR="$HOME/.qbkp/data"
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()
DATETIME=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_$DATETIME"
LATEST_LINK="latest"
LOG_FILE="$HOME/.qbkp/log/backup.log"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi


usage() {
    echo "Usage: $0 [-s source_dir] [-d backup_dir] [-i include_pattern] [-e exclude_pattern]"
    echo "  -s: Source directory (default: $DEFAULT_SOURCE_DIR)"
    echo "  -d: Backup directory (default: $DEFAULT_BACKUP_DIR)"
    echo "  -i: Include pattern (can be used multiple times)"
    echo "  -e: Exclude pattern (can be used multiple times)"
    echo ""
    echo "Pattern examples:"
    echo "  -i '*.txt'      : Include all .txt files"
    echo "  -e '*.tmp'      : Exclude all .tmp files"
    echo "  -i 'Documents/*': Include all files in Documents directory"
    echo "  -e '.cache/'    : Exclude .cache directory"
    exit 1
}

log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

while getopts "s:d:i:e:h" opt; do
    case $opt in
        s) SOURCE_DIR="$OPTARG";;
        d) BACKUP_DIR="$OPTARG";;
        i) INCLUDE_PATTERNS+=("$OPTARG");;
        e) EXCLUDE_PATTERNS+=("$OPTARG");;
        h) usage;;
        ?) usage;;
    esac
done

SOURCE_DIR="${SOURCE_DIR:-$DEFAULT_SOURCE_DIR}"
BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"

if [ ! -d "$SOURCE_DIR" ]; then
    log_message "Error: Source directory $SOURCE_DIR does not exist"
    exit 1
fi

mkdir -p "$BACKUP_DIR"
if [ ! -d "$BACKUP_DIR" ]; then
    log_message "Error: Cannot create backup directory $BACKUP_DIR"
    exit 1
fi

log_message "Starting backup from $SOURCE_DIR to $BACKUP_DIR/$BACKUP_NAME"
start_time=$(date +%s)

FILTER_RULES=()
for pattern in "${INCLUDE_PATTERNS[@]}"; do
    FILTER_RULES+=("--include=$pattern")
done
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    FILTER_RULES+=("--exclude=$pattern")
done

if [ ${#INCLUDE_PATTERNS[@]} -gt 0 ]; then
    FILTER_RULES+=("--exclude=*")
fi


log_message "Filter rules:"
for rule in "${FILTER_RULES[@]}"; do
    log_message "  $rule"
done

rsync -avP --delete \
    --link-dest="$BACKUP_DIR/$LATEST_LINK" \
    "${FILTER_RULES[@]}" \
    "$SOURCE_DIR/" \
    "$BACKUP_DIR/$BACKUP_NAME/" \
    2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    log_message "Creating manifest file"
    find "$BACKUP_DIR/$BACKUP_NAME" -type f -exec ls -lh {} \; > "$BACKUP_DIR/$BACKUP_NAME/manifest.txt"

    num_files=$(find "$BACKUP_DIR/$BACKUP_NAME" -type f | wc -l)

    log_message "Creating compressed archive"
    compression_start_time=$(date +%s)
    tar -cf - -C "$BACKUP_DIR" "$BACKUP_NAME" | pv | gzip > "$BACKUP_DIR/$BACKUP_NAME.tar.gz"
    compression_end_time=$(date +%s)

    if [ $? -eq 0 ]; then
        rm -rf "$BACKUP_DIR/$BACKUP_NAME"
        log_message "Backup completed successfully"
        
        rm -f "$BACKUP_DIR/$LATEST_LINK"
        ln -s "$BACKUP_NAME.tar.gz" "$BACKUP_DIR/$LATEST_LINK"

        cd "$BACKUP_DIR"
        ls -t *.tar.gz | tail -n +6 | xargs -r rm --
        log_message "Cleaned up old backups"

        end_time=$(date +%s)
        total_time=$((end_time - start_time))
        compression_time=$((compression_end_time - compression_start_time))
        backup_size=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)

        log_message "Backup statistics:"
        log_message "  Time taken for copying files: $((total_time - compression_time)) seconds"
        log_message "  Time taken for compression: $compression_time seconds"
        log_message "  Number of files backed up: $num_files"
        log_message "  Size of the final backup file: $backup_size"
    else
        log_message "Error: Failed to create compressed archive"
        exit 1
    fi
else
    log_message "Error: Backup failed"
    rm -rf "$BACKUP_DIR/$BACKUP_NAME"
    exit 1
fi
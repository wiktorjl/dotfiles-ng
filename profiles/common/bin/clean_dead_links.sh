#!/bin/sh

# Script to find and remove dead symbolic links in a directory
# Usage: clean_dead_links.sh <directory>

# Check if directory argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory>"
    echo "Removes all dead symbolic links in the specified directory"
    exit 1
fi

TARGET_DIR="$1"

# Check if the provided argument is a valid directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: '$TARGET_DIR' is not a valid directory"
    exit 1
fi

echo "Searching for dead symbolic links in: $TARGET_DIR"
echo "----------------------------------------"

# Counter for dead links found
count=0

# Find all symbolic links and check if they're dead
find "$TARGET_DIR" -type l 2>/dev/null | while read -r link; do
    # Check if the link target exists
    if [ ! -e "$link" ]; then
        count=$((count + 1))
        echo ""
        echo "Dead link found: $link"
        # Show what the link was pointing to
        target=$(readlink "$link")
        echo "  -> was pointing to: $target"
        
        # Ask for confirmation
        printf "Remove this dead link? [y/N]: "
        read -r response
        
        case "$response" in
            [yY]|[yY][eE][sS])
                if rm "$link"; then
                    echo "  ✓ Removed: $link"
                else
                    echo "  ✗ Failed to remove: $link"
                fi
                ;;
            *)
                echo "  Skipped: $link"
                ;;
        esac
    fi
done

# Final summary
if [ $count -eq 0 ]; then
    echo ""
    echo "No dead symbolic links found in $TARGET_DIR"
else
    echo ""
    echo "----------------------------------------"
    echo "Finished processing dead links in $TARGET_DIR"
fi
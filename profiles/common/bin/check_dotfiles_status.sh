#!/bin/bash

# Handle the label argument for the menu
if [ "$1" == "-l" ]; then
    echo "check_dotfiles_status - Check if dotfiles-ng is up to date"
    exit 0
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOTFILES_DIR="$HOME/dotfiles-ng"

# Check if dotfiles-ng directory exists
if [ ! -d "$DOTFILES_DIR" ]; then
    echo -e "${RED}Error: $DOTFILES_DIR directory not found${NC}"
    exit 1
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR" || {
    echo -e "${RED}Error: Cannot access $DOTFILES_DIR${NC}"
    exit 1
}

# Check if it's a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: $DOTFILES_DIR is not a git repository${NC}"
    exit 1
fi

# Build status line components
STATUS_PARTS=""

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Get remote URL
REMOTE_URL=$(git remote get-url origin 2>/dev/null)

# Check for uncommitted changes
UNCOMMITTED=""
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    UNCOMMITTED="*"
fi

# Check for untracked files
UNTRACKED=""
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    UNTRACKED="?"
fi

# Get remote status
REMOTE_STATUS=""
REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
if [ -n "$REMOTE_BRANCH" ]; then
    # Convert SSH URL to HTTPS for anonymous access if needed
    if [[ "$REMOTE_URL" == git@github.com:* ]]; then
        HTTPS_URL=$(echo "$REMOTE_URL" | sed 's|git@github.com:|https://github.com/|')
        REMOTE_COMMIT=$(timeout 10 git ls-remote "$HTTPS_URL" "$CURRENT_BRANCH" 2>/dev/null | cut -f1)
    else
        REMOTE_COMMIT=$(timeout 10 git ls-remote origin "$CURRENT_BRANCH" 2>/dev/null | cut -f1)
    fi

    if [ -n "$REMOTE_COMMIT" ]; then
        LOCAL_COMMIT=$(git rev-parse HEAD)
        if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
            REMOTE_STATUS="${GREEN}✓${NC}"
        else
            # Check if we have the remote commit locally
            if git cat-file -e "$REMOTE_COMMIT" 2>/dev/null; then
                AHEAD=$(git rev-list --count "$REMOTE_COMMIT"..HEAD 2>/dev/null || echo "0")
                BEHIND=$(git rev-list --count HEAD.."$REMOTE_COMMIT" 2>/dev/null || echo "0")

                if [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ]; then
                    REMOTE_STATUS="${YELLOW}±${AHEAD}/${BEHIND}${NC}"
                elif [ "$AHEAD" -gt 0 ]; then
                    REMOTE_STATUS="${YELLOW}+${AHEAD}${NC}"
                elif [ "$BEHIND" -gt 0 ]; then
                    REMOTE_STATUS="${YELLOW}-${BEHIND}${NC}"
                fi
            else
                REMOTE_STATUS="${YELLOW}?${NC}"
            fi
        fi
    else
        REMOTE_STATUS="${RED}✗${NC}"
    fi
fi

# Determine simple status
if [ -n "$REMOTE_STATUS" ] && [[ "$REMOTE_STATUS" == *"✓"* ]]; then
    echo "Dotfiles: Up to date"
else
    echo "Dotfiles: Update available"
fi
#!/bin/bash

# Setup Claude Code Docker alias
# This script sets up a Docker-based Claude Code environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info "Setting up Claude Code Docker environment..."

# 1. Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Cannot continue because Docker is required for this setup."
    print_info "Please install Docker first by running the 'docker' profile or installing it manually."
    exit 1
fi

print_success "Docker is installed and available"

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    print_warning "Docker daemon may not be running. You may need to start it with 'sudo systemctl start docker'"
fi

# 2. Create the configuration directory
CONFIG_DIR="$HOME/.claude-docker-config"
if [ ! -d "$CONFIG_DIR" ]; then
    print_info "Creating Claude Docker configuration directory at $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    print_success "Created directory: $CONFIG_DIR"
else
    print_info "Configuration directory already exists: $CONFIG_DIR"
fi

# 3. Create symlink for claude-docker script
SYMLINK_DIR="$HOME/.local/bin"
SYMLINK_PATH="$SYMLINK_DIR/claude-docker"
TARGET_SCRIPT="$HOME/apps/claude-docker/claude-docker"

if [ ! -d "$SYMLINK_DIR" ]; then
    print_info "Creating ~/.local/bin directory"
    mkdir -p "$SYMLINK_DIR"
    print_success "Created directory: $SYMLINK_DIR"
fi

if [ -f "$TARGET_SCRIPT" ]; then
    if [ -L "$SYMLINK_PATH" ]; then
        print_info "Removing existing symlink: $SYMLINK_PATH"
        rm "$SYMLINK_PATH"
    elif [ -f "$SYMLINK_PATH" ]; then
        print_warning "File exists at $SYMLINK_PATH (not a symlink). Backing up as $SYMLINK_PATH.bak"
        mv "$SYMLINK_PATH" "$SYMLINK_PATH.bak"
    fi

    print_info "Creating symlink: $SYMLINK_PATH -> $TARGET_SCRIPT"
    ln -s "$TARGET_SCRIPT" "$SYMLINK_PATH"
    print_success "Created symlink for claude-docker script"
else
    print_warning "Target script not found: $TARGET_SCRIPT"
    print_info "Symlink will be created when the script is available"
fi

# 4. Create the aliases
ALIAS_LINE="alias claude-code='docker run -it --rm -v \"\$(pwd):/code\" -v \"\$HOME/.claude-docker-config:/home/node/.claude\" -w /code node:18 bash -c \"npm install -g @anthropic-ai/claude-code && claude\"'"
CLD_ALIAS_LINE="alias cld='docker run -it --rm -v \"\$(pwd):/code\" -v \"\$HOME/.claude-docker-config:/home/node/.claude\" -w /code node:18 bash -c \"npm install -g @anthropic-ai/claude-code && claude\"'"

# Check if aliases already exist in .aliases
ALIASES_FILE="$HOME/.aliases"

if grep -q "alias claude-code=" "$ALIASES_FILE" 2>/dev/null; then
    print_warning "Claude Code alias already exists in ~/.aliases"
    print_info "Current alias:"
    grep "alias claude-code=" "$ALIASES_FILE"

    # Ask if user wants to update it
    print_info "Do you want to update the existing aliases? [y/N]"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        # Remove old aliases and add new ones
        sed -i '/alias claude-code=/d' "$ALIASES_FILE"
        sed -i '/alias cld=/d' "$ALIASES_FILE"
        echo "$ALIAS_LINE" >> "$ALIASES_FILE"
        echo "$CLD_ALIAS_LINE" >> "$ALIASES_FILE"
        print_success "Updated Claude Code aliases in ~/.aliases"
    else
        print_info "Keeping existing aliases unchanged"
    fi
else
    # Add the aliases to .aliases
    print_info "Adding Claude Code aliases to ~/.aliases"

    # Create .aliases file if it doesn't exist
    if [ ! -f "$ALIASES_FILE" ]; then
        touch "$ALIASES_FILE"
        print_info "Created ~/.aliases file"
    fi

    echo "" >> "$ALIASES_FILE"
    echo "# Claude Code Docker aliases (added by ai-clients profile)" >> "$ALIASES_FILE"
    echo "$ALIAS_LINE" >> "$ALIASES_FILE"
    echo "$CLD_ALIAS_LINE" >> "$ALIASES_FILE"
    print_success "Added Claude Code aliases to ~/.aliases"
fi

# Also handle cld alias separately if it exists without claude-code
if ! grep -q "alias claude-code=" "$ALIASES_FILE" 2>/dev/null && grep -q "alias cld=" "$ALIASES_FILE" 2>/dev/null; then
    print_info "Existing cld alias found, updating it"
    sed -i '/alias cld=/d' "$ALIASES_FILE"
    echo "$CLD_ALIAS_LINE" >> "$ALIASES_FILE"
    print_success "Updated cld alias in ~/.aliases"
fi

print_info "Setup complete!"
print_info "To use Claude Code, restart your terminal or run: source ~/.aliases"
print_info "Then you can use 'claude-code' or 'cld' commands in any directory to start Claude Code in Docker"
print_info "The claude-docker script symlink is available at ~/.local/bin/claude-docker"
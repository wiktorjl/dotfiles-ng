#!/bin/bash

# Setup logging
LOG_DIR="/home/$USER/dotfiles-ng/logs"
LOG_FILE="$LOG_DIR/deploy_dotfiles_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="$LOG_DIR/errors_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Logging functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >> "$ERROR_LOG"
}

# Colors for better TUI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# TUI helper functions
print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    log_message "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_error "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_message "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO: $1"
}

print_progress() {
    echo -e "${MAGENTA}[PROG]${NC} $1"
    log_message "PROGRESS: $1"
}

print_banner() {
    echo
    echo -e "${CYAN}+==============================================================+${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE} ____ ____ ____ ____ ____ ____ ____ ____ ____${NC}               ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE}||B |||o |||o |||t |||s |||t |||r |||a |||p ||${NC}              ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE}||__|||__|||__|||__|||__|||__|||__|||__|||__||${NC}              ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${BOLD}${WHITE}|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|/__\\\\|${NC}                   ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}                                     ${YELLOW}seed 2025${NC}                ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}                                                              ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}          ${BOLD}${MAGENTA}D O T F I L E S   D E P L O Y M E N T${NC}               ${CYAN}|${NC}"
    echo -e "${CYAN}+==============================================================+${NC}"
    echo
}
# Check if running standalone or from another script
STANDALONE=true
if [ "$1" = "--no-banner" ]; then
    STANDALONE=false
    shift
fi

if [ "$STANDALONE" = true ]; then
    clear
    print_banner
    
    print_info "This script only handles dotfiles deployment."
    print_info "For complete deployment including packages, use: ./deploy_all.sh"
    echo
fi

# First backup original files
print_progress "Backing up original dotfiles (skip if do not exist)..."
backup_count=0
if [ -f ~/.tmux.conf ]; then
    cp ~/.tmux.conf ~/.tmux.conf.bak
    print_info "Backed up ~/.tmux.conf"
    backup_count=$((backup_count + 1))
fi

if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.bak
    print_info "Backed up ~/.bashrc"
    backup_count=$((backup_count + 1))
fi

if [ -f ~/.aliases ]; then
    cp ~/.aliases ~/.aliases.bak
    print_info "Backed up ~/.aliases"
    backup_count=$((backup_count + 1))
fi

if [ -f ~/.bash_profile ]; then
    cp ~/.bash_profile ~/.bash_profile.bak
    print_info "Backed up ~/.bash_profile"
    backup_count=$((backup_count + 1))
fi

if [ $backup_count -eq 0 ]; then
    print_info "No existing dotfiles found to backup"
else
    print_success "Backed up $backup_count existing dotfiles"
fi


# Now, create symlinks to the dotfiles
print_progress "Creating symlinks to dotfiles..."
echo -e "${CYAN}+-------------------------------------------+${NC}"
echo -e "${CYAN}|${NC} ${BOLD}Creating symbolic links...${NC}              ${CYAN}|${NC}"
echo -e "${CYAN}+-------------------------------------------+${NC}"

ln -sf ~/dotfiles-ng/dotfiles/bashrc ~/.bashrc && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} bashrc -> ~/.bashrc                   ${CYAN}|${NC}"
ln -sf ~/dotfiles-ng/dotfiles/bashrc_candidates ~/.bashrc_candidates && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} bashrc_candidates -> ~/.bashrc_candidates ${CYAN}|${NC}"
ln -sf ~/dotfiles-ng/dotfiles/bash-sensible ~/.bash-sensible && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} bash-sensible -> ~/.bash-sensible     ${CYAN}|${NC}"
ln -sf ~/dotfiles-ng/dotfiles/aliases ~/.aliases && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} aliases -> ~/.aliases                 ${CYAN}|${NC}"
ln -sf ~/dotfiles-ng/dotfiles/tmux.conf ~/.tmux.conf && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} tmux.conf -> ~/.tmux.conf             ${CYAN}|${NC}"
ln -sf ~/dotfiles-ng/dotfiles/tmux-sensible.sh ~/.tmux-sensible.sh && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} tmux-sensible.sh -> ~/.tmux-sensible.sh ${CYAN}|${NC}"
ln -sf ~/dotfiles-ng/config_vars ~/.config_vars && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} config_vars -> ~/.config_vars         ${CYAN}|${NC}"
ln -sf ~/dotfiles-ng/config_vars.secret ~/.config_vars.secret && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} config_vars.secret -> ~/.config_vars.secret ${CYAN}|${NC}"

echo -e "${CYAN}+-------------------------------------------+${NC}"
print_success "All symbolic links created successfully."

# If ~/.ssh does not exist, create it
if [ ! -d ~/.ssh ]; then
    print_progress "Creating ~/.ssh directory..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    print_success "Directory ~/.ssh created with proper permissions (700)."

    touch ~/.ssh/config
    chmod 600 ~/.ssh/config
    print_success "SSH configuration file created with proper permissions (600)."

    # If SSH keys do not exist, generate them
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_progress "Generating SSH keys..."
        ssh-keygen -t rsa -b 4096 -C "noreply@wiktor.io" -f ~/.ssh/id_rsa -N ""
        print_success "SSH keys generated successfully."
    else
        print_info "SSH keys already exist."
    fi

else
    print_info "~/.ssh directory already exists."
fi  



# Check if there are any .age files to decrypt
age_files_exist=false
for file in ~/dotfiles-ng/*.age; do
    if [ -f "$file" ]; then
        age_files_exist=true
        break
    fi
done

# If .age files exist, ask user if they want to decrypt them
if [ "$age_files_exist" = true ]; then
    print_warning "Encrypted files (.age) detected in the repository."
    if [ -t 0 ]; then
        # Terminal is interactive
        echo -e "${BOLD}${YELLOW}Do you want to decrypt them now?${NC} ${CYAN}[y/N]:${NC}"
        echo -n "=> "
        read decrypt_answer
    else
        # Being run via pipe, assume no decryption by default
        print_info "Script is being run non-interactively. Skipping decryption of encrypted files."
        decrypt_answer="n"
    fi
    
    if [ "$decrypt_answer" = "y" ]; then
        print_progress "Decrypting encrypted files..."
        decrypt_count=0
        failed_count=0
        for file in ~/dotfiles-ng/*.age; do
            if [ -f "$file" ]; then
                # Decrypt the file and save it with .secret extension
                print_info "Decrypting $(basename "$file")..."
                $HOME/dotfiles-ng/lock_file.sh -d "$file"
                if [ $? -eq 0 ]; then
                    print_success "Decrypted $(basename "$file") successfully."
                    decrypt_count=$((decrypt_count + 1))
                else
                    print_error "Failed to decrypt $(basename "$file"). Please check your age key."
                    failed_count=$((failed_count + 1))
                fi
            fi
        done
        if [ $decrypt_count -gt 0 ]; then
            print_success "Successfully decrypted $decrypt_count files"
        fi
        if [ $failed_count -gt 0 ]; then
            print_warning "Failed to decrypt $failed_count files"
        fi
    else
        print_info "Skipping decryption of encrypted files."
    fi
else
    print_info "No encrypted files found."
fi

# sysfiles-full is a representation of our custom system config files, rooted at /
# So, for example, sysfiles-full/etc/ssh/ssh_config will be linked to /etc/ssh/ssh_config

# Function to validate and process a single system file
link_system_file() {
    source_file="$1"
    sysfiles_root="$2"
    relative_path="${source_file#$sysfiles_root/}"
    target_file="/$relative_path"
    target_dir="$(dirname "$target_file")"
    
    # Validate source file exists and is readable
    if [ ! -f "$source_file" ] || [ ! -r "$source_file" ]; then
        echo "Warning: Cannot read source file $source_file, skipping..."
        return 1
    fi
    
    # Create target directory with error handling
    if ! sudo mkdir -p "$target_dir"; then
        echo "Error: Failed to create directory $target_dir"
        return 1
    fi
    
    # Backup existing file if it's not already a symlink
    if [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
        backup_file="${target_file}.bak.$(date +%Y%m%d_%H%M%S)"
        print_warning "Backing up $target_file to $backup_file"
        if ! sudo cp -f "$target_file" "$backup_file"; then
            echo "Warning: Failed to backup $target_file, continuing..."
        fi
    fi
    
    # Get source file metadata before creating symlink
    source_perms=$(stat -c "%a" "$source_file" 2>/dev/null || echo "644")
    source_owner=$(stat -c "%U:%G" "$source_file" 2>/dev/null || echo "root:root")
    
    # Create symlink with error handling
    print_info "Linking $(basename "$source_file") -> $target_file"
    if ! sudo ln -sf "$source_file" "$target_file"; then
        echo "Error: Failed to create symlink $target_file"
        return 1
    fi
    
    # Apply permissions and ownership with error handling
    if ! sudo chmod "$source_perms" "$target_file"; then
        echo "Warning: Failed to set permissions on $target_file"
    fi
    
    if ! sudo chown "$source_owner" "$target_file"; then
        echo "Warning: Failed to set ownership on $target_file"
    fi
    
    return 0
}

# Main system files linking logic
link_system_files() {
    sysfiles_dir="$HOME/dotfiles-ng/sysfiles-full"
    processed_count=0
    failed_count=0
    
    echo "Linking system configuration files from sysfiles-full..."
    
    # Validate sysfiles directory exists
    if [ ! -d "$sysfiles_dir" ]; then
        echo "Directory $sysfiles_dir does not exist. Skipping linking of system configuration files."
        return 0
    fi
    
    # Create a temporary file to store the file list
    temp_file=$(mktemp)
    find "$sysfiles_dir" -type f > "$temp_file"
    
    # Process each file from the temporary file
    while IFS= read -r source_file; do
        if [ -n "$source_file" ]; then
            if link_system_file "$source_file" "$sysfiles_dir"; then
                processed_count=$((processed_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    done < "$temp_file"
    
    # Clean up temporary file
    rm -f "$temp_file"
    
    # Report results
    if [ $processed_count -gt 0 ]; then
        print_success "System files linking completed: $processed_count successful"
    fi
    if [ $failed_count -gt 0 ]; then
        print_warning "$failed_count files failed to link"
    fi
    
    if [ "$failed_count" -gt 0 ]; then
        echo "Warning: Some system files failed to link. Check the output above for details."
        return 1
    fi
    
    return 0
}

# Execute system files linking
link_system_files

# Now do some customizations

# Remove /etc/update-motd.d/10-uname if exists
if [ -f /etc/update-motd.d/10-uname ]; then
    print_progress "Removing /etc/update-motd.d/10-uname..."
    sudo rm /etc/update-motd.d/10-uname
    print_success "Removed /etc/update-motd.d/10-uname."
else
    print_info "/etc/update-motd.d/10-uname does not exist."
fi

echo
print_success "${BOLD}Dotfiles deployment completed successfully!${NC}"
echo -e "${CYAN}================================================================${NC}"

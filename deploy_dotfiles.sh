#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NON_INTERACTIVE=false

# Shared logging + TUI helpers (colors, print_*, log_message, log_error).
LOG_NAME=deploy_dotfiles
# shellcheck disable=SC1091
. "$BASE_DIR/lib/log.sh"

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
usage() {
    cat <<EOF
Usage: $0 [--no-banner] [--non-interactive]

  --no-banner        Suppress the startup banner (used when invoked from deploy_all.sh)
  --non-interactive  Skip prompts that require a terminal. NOTE: this also
                     skips age-encrypted file decryption — set up your age
                     key and run interactively if you need that step.
EOF
}

# Check if running standalone or from another script
STANDALONE=true
while [ $# -gt 0 ]; do
    case "$1" in
        --no-banner)
            STANDALONE=false
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

if [ "$STANDALONE" = true ]; then
    clear
    print_banner
    
    print_info "This script only handles dotfiles deployment."
    print_info "For complete deployment including packages, use: ./deploy_all.sh"
    echo
fi

# First backup original files.
#
# Safety: `-P` so symlinks are copied as symlinks, not dereferenced — without
# this, a symlink planted at ~/.bashrc pointing at ~/.ssh/id_rsa would have
# its target's contents copied into ~/.bashrc.bak (world-readable by default).
# We also use [ -e ] (not [ -f ]) plus -L so a symlink targeting a missing
# path is still backed up rather than silently overwritten. The .bak filename
# is timestamped so consecutive runs never overwrite prior backups.
print_progress "Backing up original dotfiles (skip if do not exist)..."
backup_count=0
skipped_count=0
backup_ts="$(date +%Y%m%d_%H%M%S)"
# backup_dotfile <target> [<expected_source>]
# If <expected_source> is given and <target> is already a symlink resolving to
# it, the file is considered already-deployed and is NOT re-backed-up. This
# avoids backup churn on repeated deploys.
backup_dotfile() {
    local path="$1"
    local expected="${2-}"
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    if [ -n "$expected" ] && [ -L "$path" ]; then
        local current
        current="$(readlink -f -- "$path" 2>/dev/null || true)"
        local resolved_expected
        resolved_expected="$(readlink -f -- "$expected" 2>/dev/null || true)"
        if [ -n "$current" ] && [ "$current" = "$resolved_expected" ]; then
            skipped_count=$((skipped_count + 1))
            return 0
        fi
    fi
    local dest="${path}.bak.${backup_ts}"
    if cp -P "$path" "$dest"; then
        print_info "Backed up $path -> $dest"
        backup_count=$((backup_count + 1))
    else
        print_warning "Failed to back up $path"
    fi
}

backup_dotfile ~/.tmux.conf  "$BASE_DIR/dotfiles/tmux.conf"
backup_dotfile ~/.bashrc     "$BASE_DIR/dotfiles/bashrc"
backup_dotfile ~/.aliases    "$BASE_DIR/dotfiles/aliases"
backup_dotfile ~/.bash_profile
backup_dotfile ~/.motd       "$BASE_DIR/dotfiles/motd"

if [ $backup_count -eq 0 ]; then
    print_info "No existing dotfiles found to backup"
else
    print_success "Backed up $backup_count existing dotfiles"
fi
if [ $skipped_count -gt 0 ]; then
    print_info "Skipped backup for $skipped_count dotfile(s) already symlinked to the repo"
fi


# Now, create symlinks to the dotfiles
print_progress "Creating symlinks to dotfiles..."
echo -e "${CYAN}+-------------------------------------------+${NC}"
echo -e "${CYAN}|${NC} ${BOLD}Creating symbolic links...${NC}              ${CYAN}|${NC}"
echo -e "${CYAN}+-------------------------------------------+${NC}"

ln -sf "$BASE_DIR/dotfiles/bashrc" ~/.bashrc && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} bashrc -> ~/.bashrc                   ${CYAN}|${NC}"
ln -sf "$BASE_DIR/dotfiles/aliases" ~/.aliases && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} aliases -> ~/.aliases                 ${CYAN}|${NC}"
ln -sf "$BASE_DIR/dotfiles/tmux.conf" ~/.tmux.conf && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} tmux.conf -> ~/.tmux.conf             ${CYAN}|${NC}"
ln -sf "$BASE_DIR/config_vars" ~/.config_vars && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} config_vars -> ~/.config_vars         ${CYAN}|${NC}"
ln -sf "$BASE_DIR/config_vars.secret" ~/.config_vars.secret && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} config_vars.secret -> ~/.config_vars.secret ${CYAN}|${NC}"
ln -sf "$BASE_DIR/dotfiles/motd" ~/.motd && echo -e "${CYAN}|${NC} ${GREEN}[OK]${NC} motd -> ~/.motd ${CYAN}|${NC}"

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

    # If SSH keys do not exist, generate them. Honour DOTFILES_SSH_PASSPHRASE
    # if set so non-interactive deploys can still produce a passphrase-protected
    # key. The historical default was empty passphrase, which is fine for an
    # ephemeral throwaway VM but unsafe on a persistent workstation. Default
    # to ed25519 (smaller, faster, modern) with RSA available via env override.
    if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
        print_progress "Generating SSH keys..."
        local_key_type="${DOTFILES_SSH_KEY_TYPE:-ed25519}"
        local_key_comment="${DOTFILES_SSH_KEY_COMMENT:-${USER}@$(hostname)}"
        local_key_passphrase="${DOTFILES_SSH_PASSPHRASE-}"
        if [ "$local_key_type" = "ed25519" ]; then
            ssh-keygen -t ed25519 -C "$local_key_comment" -f ~/.ssh/id_ed25519 -N "$local_key_passphrase"
        else
            ssh-keygen -t rsa -b 4096 -C "$local_key_comment" -f ~/.ssh/id_rsa -N "$local_key_passphrase"
        fi
        if [ -z "$local_key_passphrase" ]; then
            print_warning "Generated key has no passphrase. For a persistent workstation, set DOTFILES_SSH_PASSPHRASE before running."
        fi
        print_success "SSH keys generated successfully."
    else
        print_info "SSH keys already exist."
    fi

else
    print_info "~/.ssh directory already exists."
fi  



# Check if there are any .age files to decrypt
age_files_exist=false
for file in "$BASE_DIR"/*.age; do
    if [ -f "$file" ]; then
        age_files_exist=true
        break
    fi
done

# If .age files exist, ask user if they want to decrypt them
if [ "$age_files_exist" = true ]; then
    print_warning "Encrypted files (.age) detected in the repository."
    if [ "$NON_INTERACTIVE" = false ] && [ -t 0 ]; then
        # Terminal is interactive
        echo -e "${BOLD}${YELLOW}Do you want to decrypt them now?${NC} ${CYAN}[y/N]:${NC}"
        echo -n "=> "
        read -r decrypt_answer
    else
        # Being run via pipe, assume no decryption by default
        print_info "Script is being run non-interactively. Skipping decryption of encrypted files."
        decrypt_answer="n"
    fi
    
    if [ "$decrypt_answer" = "y" ]; then
        print_progress "Decrypting encrypted files..."
        decrypt_count=0
        failed_count=0
        for file in "$BASE_DIR"/*.age; do
            if [ -f "$file" ]; then
                # Decrypt the file and save it with .secret extension
                print_info "Decrypting $(basename "$file")..."
                "$BASE_DIR/profiles/common/bin/lock_file.sh" -d "$file"
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

# sysfiles-full is a representation of our custom system config files, rooted at /.
# For example, sysfiles-full/etc/ssh/ssh_config will be installed to /etc/ssh/ssh_config.

# Pick the install mode for a system file based on its target path. We do
# NOT read the mode from the source file in the repo because that lets a
# user-writable repo entry (e.g. `sysfiles-full/etc/cron.d/zz_pwn` at 0755)
# get root-installed at its repo-side mode — direct user→root via the next
# deploy. Instead, only well-known sensitive prefixes get reduced modes, and
# everything else falls back to 0644.
target_mode_for() {
    local target="$1"
    case "$target" in
        /etc/cron.d/*|/etc/cron.hourly/*|/etc/cron.daily/*|/etc/cron.weekly/*|/etc/cron.monthly/*)
            echo 0644 ;;
        /etc/sudoers.d/*)
            echo 0440 ;;
        /etc/ssh/sshd_config|/etc/ssh/ssh_host_*_key)
            echo 0600 ;;
        /etc/ssh/*)
            echo 0644 ;;
        /etc/profile.d/*.sh|/etc/update-motd.d/*)
            echo 0755 ;;
        *)
            echo 0644 ;;
    esac
}

# Function to validate and process a single system file
install_system_file() {
    source_file="$1"
    sysfiles_root="$2"
    # Canonicalise the source so symlinks under sysfiles-full can't redirect
    # the relative-path computation outside the managed tree.
    local resolved_source resolved_root
    resolved_source="$(readlink -f "$source_file")"
    resolved_root="$(readlink -f "$sysfiles_root")"
    if [[ "$resolved_source" != "$resolved_root"/* ]]; then
        echo "Warning: $source_file resolves outside $sysfiles_root, skipping..."
        return 1
    fi
    relative_path="${resolved_source#$resolved_root/}"
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

    # Move any existing file or symlink aside before installing the managed copy.
    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        if [ ! -L "$target_file" ] && sudo cmp -s "$source_file" "$target_file"; then
            print_info "$target_file already matches $(basename "$source_file"), skipping."
            return 0
        fi
        backup_file="${target_file}.bak.$(date +%Y%m%d_%H%M%S)"
        print_warning "Moving existing $target_file to $backup_file"
        if ! sudo mv "$target_file" "$backup_file"; then
            echo "Error: Failed to move existing $target_file"
            return 1
        fi
    fi

    local target_mode
    target_mode="$(target_mode_for "$target_file")"

    print_info "Installing $(basename "$source_file") -> $target_file (mode $target_mode)"
    # Install via a sibling temp path and atomic rename so we close the
    # window between the prior `sudo mv` of the existing target and the
    # final `install`. `install -T` makes the source-target relationship
    # unambiguous; `mv -T` then swaps it in as a single rename.
    local target_tmp="${target_file}.new.$$"
    if ! sudo install -T -o root -g root -m "$target_mode" "$source_file" "$target_tmp"; then
        echo "Error: Failed to install $target_tmp"
        return 1
    fi
    if ! sudo mv -T "$target_tmp" "$target_file"; then
        echo "Error: Failed to atomically rename $target_tmp -> $target_file"
        sudo rm -f "$target_tmp"
        return 1
    fi

    return 0
}

# Main system files linking logic
link_system_files() {
    sysfiles_dir="$BASE_DIR/sysfiles-full"
    processed_count=0
    failed_count=0
    
    echo "Installing system configuration files from sysfiles-full..."
    
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
            if install_system_file "$source_file" "$sysfiles_dir"; then
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
        print_success "System files installation completed: $processed_count successful"
    fi
    if [ $failed_count -gt 0 ]; then
        print_warning "$failed_count files failed to install"
    fi
    
    if [ "$failed_count" -gt 0 ]; then
        echo "Warning: Some system files failed to install. Check the output above for details."
        return 1
    fi
    
    return 0
}

# Execute system files linking
if ! link_system_files; then
    print_error "System files installation failed."
    exit 1
fi

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

#!/bin/sh
clear
echo
echo
echo " ____ ____ ____ ____ ____ ____ ____ ____ ____ "
echo "||B |||o |||o |||t |||s |||t |||r |||a |||p ||"
echo "||__|||__|||__|||__|||__|||__|||__|||__|||__||"
echo "|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|"
echo "                             seed 2025        "
echo
echo

# Check if script is being run interactively or via pipe
if [ -t 0 ]; then
    # Terminal is interactive
    read -p "Do you want to install base packages before deploying dotfiles? (y/n): " answer
else
    # Being run via pipe, assume default answer
    echo "Script is being run non-interactively. Defaulting to base package installation."
    answer="y"
fi

if [ "$answer" = "y" ]; then
    echo "Installing default software packages..."
    ~/dotfiles-ng/deploy_profiles.sh base networking 
    echo "Default software packages installed."
fi

# First backup original files
echo "Backing up original dotfiles (skip if do not exist)..."
if [ -f ~/.tmux.conf ]; then
    cp ~/.tmux.conf ~/.tmux.conf.bak
fi

if [ -f ~/.bashrc ]; then
    cp ~/.bashrc ~/.bashrc.bak
fi

if [ -f ~/.aliases ]; then
    cp ~/.aliases ~/.aliases.bak
fi

if [ -f ~/.bash_profile ]; then
    cp ~/.bash_profile ~/.bash_profile.bak
fi


# Now, create symlinks to the dotfiles
echo "Creating symlinks to dotfiles..."
ln -sf ~/dotfiles-ng/dotfiles/bashrc ~/.bashrc
ln -sf ~/dotfiles-ng/dotfiles/bashrc_candidates ~/.bashrc_candidates
ln -sf ~/dotfiles-ng/dotfiles/bash-sensible ~/.bash-sensible
ln -sf ~/dotfiles-ng/dotfiles/aliases ~/.aliases
ln -sf ~/dotfiles-ng/dotfiles/tmux.conf ~/.tmux.conf
ln -sf ~/dotfiles-ng/dotfiles/tmux-sensible.sh ~/.tmux-sensible.sh
ln -sf ~/dotfiles-ng/config_vars ~/.config_vars
ln -sf ~/dotfiles-ng/config_vars.secret ~/.config_vars.secret
echo "Symlinks created."

# If ~/.ssh does not exist, create it
if [ ! -d ~/.ssh ]; then
    echo "Creating ~/.ssh directory..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo "Directory ~/.ssh created."

    touch ~/.ssh/config
    chmod 600 ~/.ssh/config
    echo "SSH configuration file created."

    # If SSH keys do not exist, generate them
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo "Generating SSH keys..."
        ssh-keygen -t rsa -b 4096 -C "noreply@wiktor.io" -f ~/.ssh/id_rsa -N ""
        echo "SSH keys generated."
    else
        echo "SSH keys already exist."
    fi

else
    echo "~/.ssh directory already exists."
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
    if [ -t 0 ]; then
        # Terminal is interactive
        read -p "Encrypted files found. Do you want to decrypt them now? (y/n): " decrypt_answer
    else
        # Being run via pipe, assume no decryption by default
        echo "Script is being run non-interactively. Skipping decryption of encrypted files."
        decrypt_answer="n"
    fi
    
    if [ "$decrypt_answer" = "y" ]; then
        echo "Decrypting encrypted files..."
        for file in ~/dotfiles-ng/*.age; do
            if [ -f "$file" ]; then
                # Decrypt the file and save it with .secret extension
                echo "Decrypting $file..."
                $HOME/dotfiles-ng/lock_file.sh -d "$file"
                if [ $? -eq 0 ]; then
                    echo "Decrypted $file successfully."
                else
                    echo "Failed to decrypt $file. Please check your age key."
                fi
            fi
        done
    else
        echo "Skipping decryption of encrypted files."
    fi
else
    echo "No encrypted files found."
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
        echo "Backing up $target_file to $backup_file"
        if ! sudo cp -f "$target_file" "$backup_file"; then
            echo "Warning: Failed to backup $target_file, continuing..."
        fi
    fi
    
    # Get source file metadata before creating symlink
    source_perms=$(stat -c "%a" "$source_file" 2>/dev/null || echo "644")
    source_owner=$(stat -c "%U:%G" "$source_file" 2>/dev/null || echo "root:root")
    
    # Create symlink with error handling
    echo "Linking $source_file -> $target_file"
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
    echo "System files linking completed: $processed_count successful, $failed_count failed"
    
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
    echo "Removing /etc/update-motd.d/10-uname..."
    sudo rm /etc/update-motd.d/10-uname
    echo "Removed /etc/update-motd.d/10-uname."
else
    echo "/etc/update-motd.d/10-uname does not exist."
fi

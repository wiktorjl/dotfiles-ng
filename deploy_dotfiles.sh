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



# If dotfiles-ng contains any .age files, decrypt them
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
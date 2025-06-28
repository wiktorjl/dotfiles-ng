#!/bin/sh

# Ask user to install default software packages
read -p "Do you want to install base packages before deploying dotfiles? (y/n): " answer
if [ "$answer" = "y" ]; then
echo "Installing default software packages..."
~/dotfiles-ng/installs.sh base networking 
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
echo "Symlinks created."


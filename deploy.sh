#!/bin/sh

# Install default software packages
echo "Installing default software packages..."
~/dotfiles-ng/dotfiles/installs.sh base networking java development syssec vscode brave flatpak
echo "Default software packages installed."

# First backup original files
echo "Backing up original dotfiles..."
cp ~/.tmux.conf ~/.tmux.conf.bak
cp ~/.bashrc ~/.bashrc.bak

# Now, create symlinks to the dotfiles
echo "Creating symlinks to dotfiles..."
ln -sf ~/dotfiles-ng/dotfiles/bashrc ~/.bashrc
ln -sf ~/dotfiles-ng/dotfiles/bashrc_candidates ~/.bashrc_candidates
ln -sf ~/dotfiles-ng/dotfiles/bash-sensible ~/.bash-sensible
ln -sf ~/dotfiles-ng/dotfiles/aliases ~/.aliases
ln -sf ~/dotfiles-ng/dotfiles/config_vars ~/.config_vars
ln -sf ~/dotfiles-ng/dotfiles/tmux.conf ~/.tmux.conf
echo "Symlinks created."


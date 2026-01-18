#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Nerd Fonts..."
echo "-----------------------------------------------------"

echo "Ensuring fonts directory exists..."
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
echo "Downloading Nerd Fonts..."
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
echo "Uncompressing Nerd Fonts..."
tar xf JetBrainsMono.tar.xz
echo "Refreshing fonts cache..."
fc-cache -fv
echo "Done, fonts installed!"


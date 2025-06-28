#!/bin/sh


sudo apt update && sudo apt install -y git curl bash

if [ $? -ne 0 ]; then
    echo "Failed to install required packages. Please check your internet connection or package manager."
    exit 1
fi


cd $HOME
git clone https://github.com/wiktorjl/dotfiles-ng.git

if [ -d "$HOME/dotfiles-ng" ]; then
    echo "Dotfiles repository cloned successfully."
else
    echo "Failed to clone dotfiles repository. Please check your internet connection or the repository URL."
    exit 1
fi

$HOME/dotfiles-ng/deploy.sh


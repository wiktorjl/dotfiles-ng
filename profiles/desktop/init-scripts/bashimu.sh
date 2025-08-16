#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Bashimu..."
echo "-----------------------------------------------------"

# Check if bashimu is already installed
if command -v bashimu >/dev/null 2>&1; then
    echo "Bashimu is already installed, skipping installation..."
else
    echo "Installing Bashimu via pipx..."
    pipx install bashimu
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Bashimu."
        exit 1
    fi
    echo "Bashimu installed successfully."
fi

# Now check if we have any config files to link
echo "Checking for Bashimu config files..."
if [ -L ~/.config/llm-chat ] || [ -d ~/.config/llm-chat ]; then
    echo "Bashimu config directory already exists. Skipping linking default config files."
else
    echo "Linking default Bashimu config files..."
    mkdir -p $HOME/.config
    if [ -d $HOME/dotfiles-ng/dotfiles/.config/llm-chat ]; then
        ln -s $HOME/dotfiles-ng/dotfiles/.config/llm-chat $HOME/.config/llm-chat   
        echo "Default Bashimu config files linked to ~/.config/llm-chat."
    else
        echo "Warning: Source config directory not found at $HOME/dotfiles-ng/dotfiles/.config/llm-chat"
    fi
fi

# Now let's see if the copied config.json file is encrypted and if so, decrypt it
if [ -f $HOME/.config/llm-chat/config.json.age ]; then
    echo "Found encrypted config.json.age file. Decrypting..."
    $HOME/dotfiles-ng/lock_file.sh -d $HOME/.config/llm-chat/config.json.age
    if [ $? -eq 0 ]; then
        echo "Decrypted config.json successfully."
    else
        echo "Failed to decrypt config.json. Please check your age key."
        exit 1
    fi
else
    echo "No encrypted config.json.age file found. Skipping decryption."    
fi
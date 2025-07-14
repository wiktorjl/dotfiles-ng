#!/bin/bash


echo "-----------------------------------------------------"
echo "Attempting to install Bashimu..."
echo "-----------------------------------------------------"

pipx install bashimu

if [ $? -ne 0 ]; then
    echo "Error: Failed to install Bashimu."
    exit 1
fi

# Now check if we have any config files to link
echo "Checking for Bashimu config files..."
if [ -d ~/.config/llm-chat ]; then
    echo "Bashimu config directory already exists. Skipping copying default config files."
else
    echo "Copying default Bashimu config files..."
    mkdir -p $HOME/.config
    ln -s $HOME/dotfiles-ng/dotfiles/.config/llm-chat  $HOME/.config/llm-chat   
    echo "Default Bashimu config files linked to ~/.config/llm-chat."
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
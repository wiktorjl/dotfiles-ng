#!/bin/bash

# This script is used to encrypt/decrypt files using AGE and a passphrase.
# Once encrypted, original files are removed to ensure security.

# Usage:
# ./lock.sh <file> [<file> ...]  # To encrypt files
# ./lock.sh -d <file> [<file> ...]  # To decrypt files


# Check if the first argument is -d for decryption
if [ "$1" == "-d" ]; then
    shift  # Remove the -d argument
    overall_exit_code=0
    for file in "$@"; do
        echo "Decrypting $file..."
        age --decrypt -o "${file%.age}" "$file"
        if [ $? -eq 0 ]; then
            echo "Decryption successful. Removing encrypted file."
            rm -if "$file"
        else
            echo "Decryption failed for $file."
            overall_exit_code=1
        fi
    done
    exit $overall_exit_code
else
    overall_exit_code=0
    for file in "$@"; do
        echo "Encrypting $file..."
        age --passphrase -o "${file}.age" "$file"
        if [ $? -eq 0 ]; then
            echo "Encryption successful. Removing original file."       
            rm -f "$file"
        else
            echo "Encryption failed for $file."
            overall_exit_code=1
        fi
    done
    exit $overall_exit_code
fi  



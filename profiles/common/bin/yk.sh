#!/bin/bash

# Check if required tools are installed
check_requirements() {
    local missing_tools=()
    
    for tool in gpg gpg-agent ssh-agent openssl pcsc-tools; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: Missing required tools: ${missing_tools[*]}"
        echo "Please install them before continuing."
        exit 1
    fi
}

# Check for YubiKey presence
check_yubikey() {
    if ! gpg --card-status 2>/dev/null | grep -q "Yubikey"; then
        echo "No YubiKey detected! Please insert your YubiKey and try again."
        echo "You can verify YubiKey detection with: gpg --card-status"
        exit 1
    fi
    
    # Get YubiKey details
    echo "YubiKey detected:"
    echo "----------------"
    gpg --card-status | grep -E "Reader|Serial|Name|URL"
    echo "----------------"
}

# Configure GPG agent for SSH support
setup_gpg_agent() {
    mkdir -p ~/.gnupg
    chmod 700 ~/.gnupg
    
    cat > ~/.gnupg/gpg-agent.conf << EOL
enable-ssh-support
default-cache-ttl 60
max-cache-ttl 120
pinentry-program $(which pinentry-curses)
EOL
    
    # Restart GPG agent
    gpg-connect-agent reloadagent /bye
}

# Configure SSH to use GPG agent
setup_ssh() {
    cat >> ~/.bash_profile << EOL

# GPG SSH Agent configuration
export SSH_AUTH_SOCK=\$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
EOL
    
    source ~/.bash_profile
}

# Generate new SSH key
generate_key() {
    echo "Generating new GPG key for SSH authentication..."
    gpg --expert --full-generate-key
    
    # Get the key ID of the newly generated key
    key_id=$(gpg --list-secret-keys --keyid-format LONG | grep sec | tail -n 1 | awk '{print $2}' | cut -d'/' -f2)
    
    echo "Your GPG key ID is: $key_id"
    
    # Add authentication subkey
    echo "Follow these steps to add an authentication subkey:"
    echo "1. Type 'addkey'"
    echo "2. Select '8' for RSA (set your own capabilities)"
    echo "3. Toggle off sign and encrypt (s, e)"
    echo "4. Toggle on authenticate (a)"
    echo "5. Type 'q' when done"
    echo "6. Select keysize (4096 recommended)"
    echo "7. Set expiration"
    echo "8. Confirm with 'y'"
    echo "9. Save with 'save'"
    
    gpg --expert --edit-key "$key_id"
    
    echo "Your SSH public key is:"
    gpg --export-ssh-key "$key_id"
}

# Show current GPG card info
show_card_info() {
    echo "Current YubiKey GPG status:"
    gpg --card-status
}

# Main execution
main() {
    echo "Starting YubiKey SSH setup..."
    
    check_requirements
    check_yubikey
    setup_gpg_agent
    setup_ssh
    
    read -p "Do you want to generate a new GPG key? (y/n) " answer
    if [[ $answer == "y" ]]; then
        generate_key
    fi
    
    show_card_info
    
    echo "Setup complete! Please:"
    echo "1. Restart your terminal or run: source ~/.bash_profile"
    echo "2. Test with: ssh-add -L (should show your GPG/SSH key)"
}

main

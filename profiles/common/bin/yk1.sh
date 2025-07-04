#!/bin/bash

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Function to print success messages
success() {
    echo -e "${GREEN}$1${NC}"
}

# Function to print warning messages
warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        error "Please do not run this script as root or with sudo"
        exit 1
    fi
}

# Enhanced requirements check
check_requirements() {
    return 0
    local missing_packages=()
    local missing_commands=()
    
    # Define package to command mappings
    declare -A pkg_cmd_map=(
        ["gnupg2"]="gpg"
        ["scdaemon"]="scdaemon"
        ["pcscd"]="pcscd"
        ["pcsc-tools"]="pcsc_scan"
        ["gpg-agent"]="gpg-agent"
    )
    
    # Check if packages are installed
    for pkg in "${!pkg_cmd_map[@]}"; do
        if ! dpkg -l "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    
    # Check if commands are available
    for cmd in "${pkg_cmd_map[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    # Handle missing packages
    if [ ${#missing_packages[@]} -ne 0 ]; then
        error "Missing required packages: ${missing_packages[*]}"
        echo "Please install them with:"
        echo "sudo apt update"
        echo "sudo apt install -y ${missing_packages[*]}"
        return 1
    fi
    
    # Check service status
    if ! systemctl is-active --quiet pcscd; then
        warning "pcscd service is not running. Attempting to start..."
        sudo systemctl start pcscd
        sleep 2
    fi
    
    if ! systemctl is-active --quiet pcscd; then
        error "Failed to start pcscd service"
        return 1
    fi
    
    # Verify scdaemon configuration
    if ! pidof scdaemon >/dev/null; then
        warning "scdaemon not running. Attempting to start..."
        gpg-connect-agent "SCD KILLSCD" "SCD BYE" /bye >/dev/null 2>&1
        sleep 2
    fi
    
    # Check if necessary libraries are present
    if [ ! -f "/usr/lib/x86_64-linux-gnu/libpcsclite.so.1" ]; then
        error "Missing libpcsclite library. Please install pcscd package"
        return 1
    fi
    
    success "All required dependencies are satisfied"
    return 0
}

# Enhanced YubiKey check
check_yubikey() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ! pgrep -x "pcscd" >/dev/null; then
            warning "pcscd not running. Attempting to start..."
            sudo systemctl start pcscd
            sleep 2
        fi
        
        if pcsc_scan -n | grep -q "Yubico"; then
            success "YubiKey detected"
            echo "Checking GPG card status..."
            if ! gpg --card-status; then
                error "Failed to read GPG card status. Please check if your YubiKey is properly inserted"
                return 1
            fi
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                warning "No YubiKey detected (attempt $attempt/$max_attempts). Please insert your YubiKey..."
                sleep 3
            fi
        fi
        ((attempt++))
    done
    
    error "No YubiKey detected after $max_attempts attempts"
    return 1
}

# Configure GPG agent for SSH support
setup_gpg_agent() {
    mkdir -p ~/.gnupg
    chmod 700 ~/.gnupg
    
    # Create or update gpg-agent.conf
    cat > ~/.gnupg/gpg-agent.conf << EOL
enable-ssh-support
default-cache-ttl 3600
max-cache-ttl 7200
EOL
    
    # Create or update scdaemon.conf
    cat > ~/.gnupg/scdaemon.conf << EOL
pcsc-driver /usr/lib/x86_64-linux-gnu/libpcsclite.so.1
pcsc-shared
EOL
    
    # Restart gpg-agent
    gpg-connect-agent KILLAGENT /bye
    gpg-connect-agent /bye
    
    success "GPG agent configured successfully"
}

# Configure shell for SSH support
setup_shell() {
    # Add GPG SSH agent to shell config if not already present
    if ! grep -q "SSH_AUTH_SOCK.*gpgconf" ~/.bashrc; then
        echo -e "\n# GPG SSH Agent Configuration" >> ~/.bashrc
        echo 'export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)' >> ~/.bashrc
        echo 'gpg-connect-agent updatestartuptty /bye > /dev/null' >> ~/.bashrc
        success "Shell configuration updated"
    else
        success "Shell configuration already set up"
    fi
    
    # Source the new configuration
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    gpg-connect-agent updatestartuptty /bye > /dev/null
}

# Generate GPG key
generate_key() {
    echo "Starting GPG key generation process..."
    echo -e "\nPlease follow these steps:"
    echo "1. Select (8) RSA (set your own capabilities)"
    echo "2. Toggle capabilities:"
    echo "   - Toggle off encryption (e)"
    echo "   - Toggle off signing (s)"
    echo "   - Toggle off authentication (a)"
    echo "   - Certify capability should remain"
    echo "3. Choose (q) when done"
    echo "4. Select 4096 bits for key size"
    echo "5. Set expiration as needed (e.g., 2y for 2 years)"
    echo "6. Enter your name and email"
    echo ""
    read -p "Press Enter to continue..."
    
    gpg --expert --full-generate-key
    
    # Get the key ID
    key_id=$(gpg --list-secret-keys --keyid-format long | grep sec | head -n 1 | awk '{print $2}' | cut -d'/' -f2)
    
    if [ -z "$key_id" ]; then
        error "Failed to generate GPG key or retrieve key ID"
        return 1
    fi
    
    success "Key generated. Key ID: $key_id"
    echo -e "\nNow adding authentication subkey..."
    echo "Please follow these steps in the GPG edit menu:"
    echo "1. Type 'addkey'"
    echo "2. Select (8) RSA (set your own capabilities)"
    echo "3. Toggle capabilities:"
    echo "   - Toggle off signing (s)"
    echo "   - Toggle off encryption (e)"
    echo "   - Ensure authentication (a) is on"
    echo "4. Choose (q) when done"
    echo "5. Select 4096 bits"
    echo "6. Set same expiration as master key"
    echo "7. Confirm with 'y'"
    echo "8. Type 'save' to finish"
    echo ""
    read -p "Press Enter to continue..."
    
    gpg --expert --edit-key "$key_id"
    
    echo -e "\nYour SSH public key is:"
    gpg --export-ssh-key "$key_id"
}

# Main execution
main() {
    echo "Starting YubiKey SSH setup..."
    
    check_root || exit 1
    
    if ! check_requirements; then
        exit 1
    fi
    
    if ! check_yubikey; then
        exit 1
    fi
    
    setup_gpg_agent
    setup_shell
    
    read -p "Do you want to generate a new GPG key? (y/n) " answer
    if [[ $answer == "y" ]]; then
        generate_key
    fi
    
    success "\nSetup complete! Please:"
    echo "1. Log out and log back in, or source your ~/.bashrc"
    echo "2. Test with: ssh-add -L (should show your GPG/SSH key)"
    echo "3. Your YubiKey should now work for SSH authentication"
}

main

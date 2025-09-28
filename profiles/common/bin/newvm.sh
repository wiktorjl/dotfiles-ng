#!/bin/bash

# VM Clone and Setup Script
# Usage: ./vm-clone-and-setup.sh <source-domain> <new-domain> <new-hostname>

set -e  # Exit on any error

# Check arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <source-domain> <new-domain> <new-hostname>"
    echo "Example: $0 template-vm my-new-vm web-server-01"
    exit 1
fi

SOURCE_DOMAIN=$1
NEW_DOMAIN=$2
NEW_HOSTNAME=$3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to wait for guest agent
wait_for_guest_agent() {
    local domain=$1
    local max_attempts=30
    local attempt=1
    
    log "Waiting for QEMU guest agent to become available..."
    
    while [ $attempt -le $max_attempts ]; do
        if virsh qemu-agent-command "$domain" '{"execute":"guest-ping"}' &>/dev/null; then
            log "Guest agent is ready"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    error "Guest agent did not become available within $((max_attempts * 2)) seconds"
}

# Function to execute command via guest agent and get output
guest_exec() {
    local domain=$1
    local command=$2
    
    # Execute command and get PID
    local response=$(virsh qemu-agent-command "$domain" "{\"execute\":\"guest-exec\", \"arguments\":{\"path\":\"/bin/bash\", \"arg\":[\"-c\", \"$command\"], \"capture-output\": true}}")
    
    if ! echo "$response" | grep -q '"return"'; then
        error "Failed to execute command: $command"
    fi
    
    local pid=$(echo "$response" | grep -o '"pid":[0-9]*' | cut -d':' -f2)
    
    # Wait a moment for command to complete
    sleep 2
    
    # Get the result
    local result=$(virsh qemu-agent-command "$domain" "{\"execute\":\"guest-exec-status\", \"arguments\":{\"pid\":$pid}}")
    
    # Check if command completed successfully
    if echo "$result" | grep -q '"exited":true'; then
        local exit_code=$(echo "$result" | grep -o '"exitcode":[0-9]*' | cut -d':' -f2)
        if [ "$exit_code" -ne 0 ]; then
            warn "Command exited with code $exit_code: $command"
            return $exit_code
        fi
        
        # Extract and decode output if available
        if echo "$result" | grep -q '"out-data"'; then
            echo "$result" | grep -o '"out-data":"[^"]*"' | cut -d'"' -f4 | base64 -d 2>/dev/null || true
        fi
    else
        error "Command did not complete: $command"
    fi
}

# Function to get VM IP address
get_vm_ip() {
    local domain=$1
    local max_attempts=20
    local attempt=1
    
    log "Waiting for IP address assignment..."
    
    while [ $attempt -le $max_attempts ]; do
        # Try virsh domifaddr first (works with DHCP)
        local ip=$(virsh domifaddr "$domain" 2>/dev/null | awk '/ipv4/ {print $4}' | cut -d'/' -f1 | head -1)
        
        if [ -n "$ip" ] && [ "$ip" != "N/A" ]; then
            echo "$ip"
            return 0
        fi
        
        # Fallback: try guest agent
        if virsh qemu-agent-command "$domain" '{"execute":"guest-ping"}' &>/dev/null; then
            ip=$(guest_exec "$domain" "hostname -I | awk '{print \$1}'" 2>/dev/null | tr -d '\n\r' || true)
            if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "$ip"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 3
        ((attempt++))
    done
    
    warn "Could not determine IP address within $((max_attempts * 3)) seconds"
    return 1
}

# Main script execution
log "Starting VM clone and setup process..."

# Check if source domain exists
if ! virsh dominfo "$SOURCE_DOMAIN" &>/dev/null; then
    error "Source domain '$SOURCE_DOMAIN' does not exist"
fi

# Check if new domain already exists
if virsh dominfo "$NEW_DOMAIN" &>/dev/null; then
    error "Domain '$NEW_DOMAIN' already exists"
fi

# Step 1: Clone the VM
log "Cloning VM '$SOURCE_DOMAIN' to '$NEW_DOMAIN'..."
if ! virt-clone --original "$SOURCE_DOMAIN" --name "$NEW_DOMAIN" --auto-clone; then
    error "Failed to clone VM"
fi
log "VM cloned successfully"

# Step 2: Start the cloned VM
log "Starting VM '$NEW_DOMAIN'..."
if ! virsh start "$NEW_DOMAIN"; then
    error "Failed to start VM"
fi
log "VM started successfully"

# Step 3: Wait for guest agent and set hostname
wait_for_guest_agent "$NEW_DOMAIN"

log "Setting hostname to '$NEW_HOSTNAME'..."

# Set hostname (works on most Linux distributions)
guest_exec "$NEW_DOMAIN" "hostnamectl set-hostname '$NEW_HOSTNAME' 2>/dev/null || echo '$NEW_HOSTNAME' > /etc/hostname"

# Update /etc/hosts
guest_exec "$NEW_DOMAIN" "sed -i '/127.0.1.1/d' /etc/hosts && echo '127.0.1.1 $NEW_HOSTNAME' >> /etc/hosts"

# For systems that need it, update the hostname immediately
guest_exec "$NEW_DOMAIN" "hostname '$NEW_HOSTNAME' 2>/dev/null || true"

log "Hostname set successfully"

# Step 4: Get and return IP address
log "Retrieving IP address..."
ip_address=$(get_vm_ip "$NEW_DOMAIN")

if [ -n "$ip_address" ]; then
    log "VM setup completed successfully!"
    echo ""
    echo "==================================="
    echo "VM Details:"
    echo "  Name: $NEW_DOMAIN"
    echo "  Hostname: $NEW_HOSTNAME"
    echo "  IP Address: $ip_address"
    echo "==================================="
    echo ""
    echo "IP Address: $ip_address"
else
    warn "VM is running but IP address could not be determined"
    echo "VM Name: $NEW_DOMAIN"
    echo "Hostname: $NEW_HOSTNAME"
    echo "Status: Running (check IP manually with 'virsh domifaddr $NEW_DOMAIN')"
fi

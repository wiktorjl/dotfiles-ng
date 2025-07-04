#!/bin/bash

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[31mThis script must be run as root\033[0m" # Red
   exit 1
fi

# Color codes
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m' # No Color

# --- Variables ---
DEFAULT_TEMPLATE="template-debian-x"  # Default source VM name
DISK_PATH="/var/lib/libvirt/images"  # Path where VM disks are stored (Informational)
INITIAL_WAIT=10                      # Initial seconds to wait for VM boot
MAX_POLL=45                          # Max seconds to poll for IP after initial wait
HOSTNAME=""
SSH_USER=""                          # Default to empty, requires -s option for SSH actions
DO_SSH=false                         # Default SSH interaction to false unless -s is used

# Determine SUDO_USER safely
CURRENT_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
DEFAULT_SSH_KEY_PATH="/home/$CURRENT_USER/.ssh/id_homelan" # Using id_homelan

# --- Function to check SSH connectivity ---
check_ssh() {
    local user=$1
    local ip=$2
    local key=$3
    echo -e "${BLUE}Checking SSH readiness for $user@$ip using key $key...${NC}"
    sudo -u "$CURRENT_USER" ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -i "$key" "$user@$ip" exit 0 > /dev/null 2>&1
    return $?
}

# --- Parse command line options ---
while getopts "n:s:" opt; do
    case $opt in
        n) HOSTNAME="$OPTARG";;
        s) SSH_USER="$OPTARG"; DO_SSH=true;;
        ?) echo -e "${RED}Usage: $0 [-n hostname] [-s username] [source-vm] <new-vm-name>${NC}"
           echo -e "  -n: Set hostname for the new VM (requires guest agent or SSH access)"
           echo -e "  -s: SSH username for configuration and optional final login (key: $DEFAULT_SSH_KEY_PATH)"
           echo -e "  If source-vm is omitted, '$DEFAULT_TEMPLATE' will be used"
           exit 1;;
    esac
done

# Shift past the options
shift $((OPTIND-1))

# --- Set source and new VM names ---
# Corrected logic from previous iteration
if [ -n "$2" ]; then
    SOURCE_VM="$1"
    NEW_VM="$2"
    echo -e "${BLUE}Using specified source VM: '$SOURCE_VM'${NC}"
elif [ -n "$1" ]; then
    SOURCE_VM="$DEFAULT_TEMPLATE"
    NEW_VM="$1"
    echo -e "${BLUE}Using default source VM: '$SOURCE_VM'${NC}"
else
    SOURCE_VM="$DEFAULT_TEMPLATE"
    NEW_VM=""
    echo -e "${BLUE}No VM name provided. Usage requires a new VM name.${NC}"
fi

# --- Input Validation ---
if [ -z "$NEW_VM" ]; then
    echo -e "${RED}Error: Please provide a name for the new VM${NC}"
    echo -e "${RED}Usage: $0 [-n hostname] [-s username] [source-vm] <new-vm-name>${NC}"
    exit 1
fi

if [ -z "$HOSTNAME" ]; then
    echo -e "${YELLOW}No hostname specified via -n, using VM name '$NEW_VM' as hostname.${NC}"
    HOSTNAME="$NEW_VM"
fi

if ! virsh list --all | grep -qw "$SOURCE_VM"; then
    echo -e "${RED}Source VM '$SOURCE_VM' not found${NC}"
    exit 1
fi

if virsh list --all | grep -qw "$NEW_VM"; then
    echo -e "${RED}Target VM '$NEW_VM' already exists${NC}"
    exit 1
fi

# --- Clone the VM ---
echo -e "${BLUE}Cloning VM from $SOURCE_VM to $NEW_VM...${NC}"
virt-clone --original "$SOURCE_VM" --name "$NEW_VM" --auto-clone

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to clone VM${NC}"
    exit 1
fi
echo -e "${GREEN}VM '$NEW_VM' cloned successfully.${NC}"

# --- Start the new VM ---
echo -e "${BLUE}Starting new VM '$NEW_VM'...${NC}"
virsh start "$NEW_VM"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start new VM '$NEW_VM'${NC}"
    exit 1
fi
echo -e "${GREEN}VM '$NEW_VM' started successfully${NC}"

# --- Get MAC Address ---
echo -e "${BLUE}Getting MAC address for $NEW_VM's primary network interface...${NC}"
MAC_ADDRESS=$(virsh dumpxml "$NEW_VM" 2>/dev/null | grep -oP "<mac address='\K[^']+(?=')" | head -n1)

if [ -z "$MAC_ADDRESS" ]; then
    echo -e "${RED}Error: Could not determine any MAC address for '$NEW_VM'. Check network configuration in VM XML.${NC}"
    echo -e "${YELLOW}Run 'virsh dumpxml $NEW_VM' to inspect the VM's network interfaces.${NC}"
    exit 1
else
    echo -e "${GREEN}Found MAC Address: $MAC_ADDRESS${NC}"
fi


# --- Determine Network Type ---
echo -e "${BLUE}Determining network type associated with MAC $MAC_ADDRESS...${NC}"
INTERFACE_BLOCK=$(virsh dumpxml "$NEW_VM" | sed -n "/<mac address='$MAC_ADDRESS'/,/<\/interface>/p")
NETWORK_NAME=$(echo "$INTERFACE_BLOCK" | grep -oP "<source network='\K[^']+(?=')")
BRIDGE_NAME=$(echo "$INTERFACE_BLOCK" | grep -oP "<source bridge='\K[^']+(?=')")

if [ -n "$NETWORK_NAME" ]; then
    NETWORK_TYPE="nat"
    echo -e "${GREEN}Detected NAT network source: '$NETWORK_NAME'${NC}"
elif [ -n "$BRIDGE_NAME" ]; then
    NETWORK_TYPE="bridge"
    echo -e "${GREEN}Detected bridge network: '$BRIDGE_NAME'${NC}"
else
    NETWORK_TYPE="other"
    echo -e "${YELLOW}Detected network type: Other/Unknown (MAC: $MAC_ADDRESS). IP detection may be limited.${NC}"
fi

# --- Display VM info ---
echo -e "\n${BLUE}New VM information:${NC}"
virsh dominfo "$NEW_VM"

# --- Wait for VM to boot ---
echo -e "\n${BLUE}Waiting $INITIAL_WAIT seconds for VM to boot...${NC}"
sleep "$INITIAL_WAIT"

# --- Set hostname via QEMU Agent (Best effort) ---
# (Hostname setting logic remains the same)
echo -e "${BLUE}Attempting to set hostname to '$HOSTNAME' via QEMU Guest Agent...${NC}"
agent_hostname_set=false
if virsh qemu-agent-command "$NEW_VM" "{\"execute\":\"guest-set-hostname\", \"arguments\":{\"hostname\":\"$HOSTNAME\"}}" --timeout 10 > /dev/null 2>&1; then
    echo -e "${GREEN}Attempted to set hostname to '$HOSTNAME' via guest agent (guest-set-hostname).${NC}"
    agent_hostname_set=true
elif virsh qemu-agent-command "$NEW_VM" "{\"execute\":\"guest-exec\", \"arguments\":{\"path\":\"hostnamectl\", \"arg\":[\"set-hostname\", \"$HOSTNAME\"]}}" --timeout 10 > /dev/null 2>&1; then
     echo -e "${GREEN}Attempted to set hostname to '$HOSTNAME' via guest agent (fallback guest-exec hostnamectl).${NC}"
     agent_hostname_set=true
else
    echo -e "${YELLOW}Warning: Failed to set hostname via QEMU guest agent. Will attempt via SSH if possible.${NC}"
fi


# --- Poll for IP address ---
echo -e "\n${BLUE}Checking for IP address (up to $MAX_POLL seconds). Method priority based on network type: $NETWORK_TYPE${NC}"
IP=""
MAC_LOWER=$(echo "$MAC_ADDRESS" | tr '[:upper:]' '[:lower:]')

# Ensure the network is active for NAT
if [ "$NETWORK_TYPE" = "nat" ] && [ -n "$NETWORK_NAME" ]; then
    virsh net-info "$NETWORK_NAME" | grep -q "Active:.*yes" || virsh net-start "$NETWORK_NAME" 2>/dev/null
fi

for i in $(seq 1 "$MAX_POLL"); do
    echo -n "." # Progress indicator
    CURRENT_IP=""

    if [ "$NETWORK_TYPE" = "nat" ] && [ -n "$NETWORK_NAME" ]; then
        CURRENT_IP=$(virsh net-dhcp-leases "$NETWORK_NAME" 2>/dev/null | grep -i "$MAC_ADDRESS" | awk '{print $5}' | cut -d'/' -f1)
        if [ -n "$CURRENT_IP" ] && [[ "$CURRENT_IP" != "0.0.0.0" ]]; then
            IP="$CURRENT_IP"
            echo -e "\n${GREEN}IP Address found via DHCP Leases ('$NETWORK_NAME'): $IP${NC}"
            break
        fi
    elif [ "$NETWORK_TYPE" = "bridge" ]; then
        ip link show | grep -q "$BRIDGE_NAME" && ping -c 2 -b "$(ip -4 addr show "$BRIDGE_NAME" | grep -oP 'inet \K[\d.]+(?=/)')" > /dev/null 2>&1
        CURRENT_IP=$(arp -an 2>/dev/null | grep -i "$MAC_LOWER" | grep -oP '\(\K[0-9.]+(?=\))')
        if [ -n "$CURRENT_IP" ] && [[ "$CURRENT_IP" != "0.0.0.0" ]]; then
            IP="$CURRENT_IP"
            echo -e "\n${GREEN}IP Address found via host ARP cache: $IP${NC}"
            break
        fi
    fi
    # Fallback methods (domifaddr, agent) remain the same

    # --- Fallback Methods ---
    if [ -z "$IP" ]; then
        # Fallback 1: domifaddr with lease source
        CURRENT_IP=$(virsh domifaddr "$NEW_VM" --interface "$MAC_ADDRESS" --source lease 2>/dev/null | grep -Eiv '^(::1|127\.0\.0\.1|fe80::|0\.0\.0\.0)' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        if [ -n "$CURRENT_IP" ]; then
            IP="$CURRENT_IP"
            echo -e "\n${YELLOW}IP Address found via domifaddr/lease (Fallback 1): $IP${NC}"
            break
        fi

        # Fallback 2: domifaddr with agent source (increase timeout)
        CURRENT_IP=$(virsh domifaddr "$NEW_VM" --interface "$MAC_ADDRESS" --source agent 2>/dev/null | grep -Eiv '^(::1|127\.0\.0\.1|fe80::|0\.0\.0\.0)' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        if [ -n "$CURRENT_IP" ]; then
            IP="$CURRENT_IP"
            echo -e "\n${YELLOW}IP Address found via domifaddr/agent (Fallback 2): $IP${NC}"
            break
        fi

        # Fallback 3: QEMU agent with longer timeout
        AGENT_IP=$(virsh qemu-agent-command "$NEW_VM" '{"execute":"guest-network-get-interfaces"}' --timeout 5 2>/dev/null | \
                   grep -o '"ip-address":"[^"]*"' | \
                   grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
                   grep -Ev '^(127\.0\.0\.1|0\.0\.0\.0)$' | \
                   head -n1)
        if [ -n "$AGENT_IP" ]; then
            IP="$AGENT_IP"
            echo -e "\n${YELLOW}IP Address found via qemu-agent (Fallback 3): $IP${NC}"
            break
        fi
    fi

    sleep 1
done
echo # Newline after dots

# --- Check if IP was found ---
if [ -z "$IP" ]; then
    echo -e "\n${RED}Error: Could not determine a usable IPv4 address for '$NEW_VM' (MAC: $MAC_ADDRESS) within $((INITIAL_WAIT + MAX_POLL)) seconds.${NC}"
    echo -e "${YELLOW}Troubleshooting steps based on Network Type ($NETWORK_TYPE):${NC}"
    if [ "$NETWORK_TYPE" = "nat" ]; then
        echo -e "${YELLOW} - Check DHCP leases on network '$NETWORK_NAME': 'sudo virsh net-dhcp-leases $NETWORK_NAME'${NC}"
        echo -e "${YELLOW} - Ensure DHCP client is running in the VM.${NC}"
    else # Bridge
        echo -e "${YELLOW} - Check host ARP cache: 'arp -an' (try pinging broadcast or other IPs on the subnet from VM/host).${NC}"
        echo -e "${YELLOW} - Verify bridge configuration and VM network settings.${NC}"
    fi
    echo -e "${YELLOW} - Check QEMU guest agent status inside VM ('systemctl status qemu-guest-agent').${NC}"
    echo -e "${YELLOW} - Check VM console ('virsh console $NEW_VM') for network errors.${NC}"
    exit 1
fi

# --- Configure via SSH if username is provided ---
# (SSH Configuration logic remains the same, using the found $IP)
ssh_ready=false
if [ "$DO_SSH" = true ] && [ -n "$SSH_USER" ]; then
    SSH_KEY_PATH="$DEFAULT_SSH_KEY_PATH"
    echo -e "\n${BLUE}SSH User '$SSH_USER' provided. Attempting SSH configuration using key '$SSH_KEY_PATH'. Target IP: $IP${NC}"

    echo -e "${BLUE}Waiting a few seconds for SSH daemon on $NEW_VM ($IP)...${NC}"
    sleep 5

    for attempt in {1..5}; do
        if check_ssh "$SSH_USER" "$IP" "$SSH_KEY_PATH"; then
            echo -e "${GREEN}SSH connection test successful to $IP.${NC}"
            ssh_ready=true
            break
        else
            echo -e "${YELLOW}SSH connection test failed to $IP (Attempt $attempt/5). Waiting 5s...${NC}"
            sleep 5
        fi
    done

    if ! $ssh_ready; then
        echo -e "${RED}Error: Could not establish initial SSH connection to $SSH_USER@$IP.${NC}"
        exit 1
    fi

    if $ssh_ready; then
        # Set /etc/hosts
        echo -e "${BLUE}Attempting to update /etc/hosts on $NEW_VM ($IP) via SSH...${NC}"
        HOSTS_CMD="sudo sed -i '/^127\\.0\\.1\\.1/d' /etc/hosts && echo '127.0.1.1 $HOSTNAME' | sudo tee -a /etc/hosts > /dev/null"
        if sudo -u "$CURRENT_USER" ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$IP" "$HOSTS_CMD"; then
            echo -e "${GREEN}Successfully updated /etc/hosts on $NEW_VM.${NC}"
        else
            echo -e "${RED}Error: Failed to update /etc/hosts on $NEW_VM ($IP) via SSH.${NC}"
            DO_SSH=false
        fi

        # Set hostname via SSH (if agent failed)
        if ! $agent_hostname_set; then
            echo -e "${BLUE}Attempting to set hostname to '$HOSTNAME' on $IP via SSH (Agent method failed)...${NC}"
            HOSTNAME_CMD="sudo hostnamectl set-hostname $HOSTNAME"
            if sudo -u "$CURRENT_USER" ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$IP" "$HOSTNAME_CMD"; then
                 echo -e "${GREEN}Successfully set hostname to '$HOSTNAME' via SSH.${NC}"
            else
                 echo -e "${RED}Error: Failed to set hostname via SSH on $IP.${NC}"
            fi
        fi
    fi

elif [ -n "$SSH_USER" ]; then
     echo -e "${YELLOW}SSH User provided but SSH operations not triggered (DO_SSH=false). Skipping SSH config.${NC}"
     DO_SSH=false
else
    echo -e "\n${YELLOW}No SSH user provided (-s option). Skipping SSH configuration steps.${NC}"
    DO_SSH=false
fi

# --- Optional Interactive SSH Session ---
# (Interactive SSH logic remains the same)
if [ "$DO_SSH" = true ] && $ssh_ready; then
    echo -e "\n${BLUE}Attempting interactive SSH into $NEW_VM as $SSH_USER@$IP...${NC}"
    echo -e "${YELLOW}(Use 'exit' to return to this script)${NC}"
    sudo -u "$CURRENT_USER" ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$IP"
    # Check exit status if needed
    echo -e "${GREEN}SSH session finished.${NC}"
elif [ "$DO_SSH" = true ] && ! $ssh_ready; then
     echo -e "\n${YELLOW}Skipping interactive SSH because initial connection test to $IP failed.${NC}"
elif [ -n "$SSH_USER" ] && ! [ "$DO_SSH" = true ]; then
     echo -e "\n${YELLOW}Skipping interactive SSH session as config steps failed or session was not requested/enabled.${NC}"
fi

echo -e "\n${GREEN}Script finished.${NC}"
exit 0

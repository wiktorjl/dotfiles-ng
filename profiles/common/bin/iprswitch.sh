#!/bin/bash

# Constants
CLEARNET_GW="10.16.0.1"
VPN_GW="10.16.0.7"
DEFAULT_ROUTE="default"

# Function to display usage instructions
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --clearnet    Switch to clearnet gateway ($CLEARNET_GW)"
    echo "  -v, --vpn         Switch to VPN gateway ($VPN_GW)"
    echo "  -s, --status      Show current routing status"
    echo "  -l, --location    Show current IP location info"
    echo "  -h, --help        Display this help message"
    exit 1
}

# Function to check if script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Error: This script must be run as root"
        exit 1
    fi
}

# Function to switch default gateway
switch_gateway() {
    local new_gw="$1"
    
    # Delete existing default route
    if ip route | grep -q "^$DEFAULT_ROUTE"; then
        ip route delete "$DEFAULT_ROUTE"
    fi
    
    # Add new default route
    if ! ip route add "$DEFAULT_ROUTE" via "$new_gw"; then
        echo "Error: Failed to set default route via $new_gw"
        exit 1
    fi
    
    echo "Successfully switched default gateway to $new_gw"
}

# Function to show current routing status
show_status() {
    echo "Current IP Routes:"
    echo "----------------"
    ip route show
    echo -e "\nCurrent Default Gateway:"
    ip route | grep "^$DEFAULT_ROUTE" || echo "No default route set"
}

# Function to get IP location information
get_location() {
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required but not installed"
        exit 1
    fi
    
    echo "Current IP Location Information:"
    echo "------------------------------"
    curl -s ipinfo.io
}

# Main script logic
if [ $# -eq 0 ]; then
    usage
fi

# Parse command line options
while [ $# -gt 0 ]; do
    case "$1" in
        -c|--clearnet)
            check_root
            switch_gateway "$CLEARNET_GW"
            ;;
        -v|--vpn)
            check_root
            switch_gateway "$VPN_GW"
            ;;
        -s|--status)
            show_status
            ;;
        -l|--location)
            get_location
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
    shift
done

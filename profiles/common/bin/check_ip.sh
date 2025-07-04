#!/bin/bash

# Get the current host's IP address
MY_IP=$(curl -s ifconfig.me)

# Get the IP address of the host rabbit.lan
OT_IP=$(ssh seed@rabbit.lan "curl -s ifconfig.me")

# Check if both IPs were obtained successfully
if [ -z "$MY_IP" ]; then
    echo "Failed to retrieve MY_IP"
    exit 1
fi

if [ -z "$OT_IP" ]; then
    echo "Failed to retrieve OT_IP for rabbit.lan"
    exit 1
fi

# Compare the IP addresses
if [ "$MY_IP" == "$OT_IP" ]; then
    echo "The IP addresses are equal."
else
    echo "The IP addresses are not equal."
fi


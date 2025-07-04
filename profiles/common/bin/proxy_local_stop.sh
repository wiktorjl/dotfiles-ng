#!/bin/bash

# Kill the SSH SOCKS proxy if it's running
if [ -f /tmp/ssh_socks_proxy.pid ]; then
    SSH_PID=$(cat /tmp/ssh_socks_proxy.pid)
    kill $SSH_PID
    rm /tmp/ssh_socks_proxy.pid
    echo "SSH SOCKS proxy stopped."
else
    echo "SSH SOCKS proxy not running."
fi

gsettings set org.gnome.system.proxy mode 'none'
gsettings reset org.gnome.system.proxy.socks host
gsettings reset org.gnome.system.proxy.socks port

exit 0


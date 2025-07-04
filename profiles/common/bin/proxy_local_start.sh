#!/bin/bash

# Parameters
SERVER_USER="seed"
SERVER_IP="sneak.lan"
LOCAL_PORT="1080"

# Start SSH SOCKS proxy
ssh -D $LOCAL_PORT -q -C -N $SERVER_USER@$SERVER_IP &
SSH_PID=$!

echo "SSH SOCKS proxy started on port $LOCAL_PORT (PID: $SSH_PID)"
echo $SSH_PID > /tmp/ssh_socks_proxy.pid

gsettings set org.gnome.system.proxy mode 'manual'
gsettings set org.gnome.system.proxy.socks host 'localhost'
gsettings set org.gnome.system.proxy.socks port $LOCAL_PORT

exit 0

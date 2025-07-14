echo "-----------------------------------------------------"
echo "Attempting to install Docker..."
echo "-----------------------------------------------------"

# Check if Docker group already exists
if getent group docker > /dev/null; then
    echo "Docker group already exists. Skipping group creation."
else
    echo "Creating Docker group..."
    sudo groupadd docker
fi

sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker    
echo "Docker installation completed successfully."
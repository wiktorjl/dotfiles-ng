echo "-----------------------------------------------------"
echo "Attempting to configure unattended upgrades..."
echo "-----------------------------------------------------"

# If /etc/apt/apt.conf.d/20auto-upgrades does not have the following entries, add them
# APT::Periodic::Update-Package-Lists "1";
# APT::Periodic::Unattended-Upgrade "1";

AUTO_UPGRADES_FILE="/etc/apt/apt.conf.d/20auto-upgrades"

# Check if the file exists
if [ ! -f "$AUTO_UPGRADES_FILE" ]; then
    echo "Creating $AUTO_UPGRADES_FILE..."
    sudo tee "$AUTO_UPGRADES_FILE" > /dev/null <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
    echo "✓ Created auto-upgrades configuration"
else
    # Check if required entries exist
    UPDATE_LISTS=$(grep -c '^APT::Periodic::Update-Package-Lists "1";' "$AUTO_UPGRADES_FILE" 2>/dev/null || echo 0)
    UNATTENDED=$(grep -c '^APT::Periodic::Unattended-Upgrade "1";' "$AUTO_UPGRADES_FILE" 2>/dev/null || echo 0)
    
    if [ "$UPDATE_LISTS" -eq 0 ] || [ "$UNATTENDED" -eq 0 ]; then
        echo "Updating $AUTO_UPGRADES_FILE..."
        
        # Backup existing file
        sudo cp "$AUTO_UPGRADES_FILE" "${AUTO_UPGRADES_FILE}.bak"
        
        # Add missing entries
        if [ "$UPDATE_LISTS" -eq 0 ]; then
            echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee -a "$AUTO_UPGRADES_FILE" > /dev/null
            echo "✓ Added Update-Package-Lists configuration"
        fi
        
        if [ "$UNATTENDED" -eq 0 ]; then
            echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a "$AUTO_UPGRADES_FILE" > /dev/null
            echo "✓ Added Unattended-Upgrade configuration"
        fi
    else
        echo "✓ Unattended upgrades already configured"
    fi
fi

echo "-----------------------------------------------------"
echo "Unattended upgrades configuration complete"
echo "-----------------------------------------------------"

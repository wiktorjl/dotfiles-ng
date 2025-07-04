#!/bin/bash


#
# Execute this to mount a drive
# cryptsetup luksOpen /dev/nvme0n1p1 seed_home
# mount /dev/mapper/seed_home data/
# 
# Make it mount automatic? Verify.
# sudo udisks --mount /dev/mapper/my_encrypted_volume


echo "Opening Photos drive..."
cryptsetup luksOpen --key-file /etc/luks/photos_keyfile.bin /dev/disk/by-uuid/5296bdb1-8bef-466b-b77b-d139fb100d26 photos
#notify-send "Media disk decryption" "Photos have been decrypted" --icon=dialog-information
echo "Opening Videos drive..."
cryptsetup luksOpen --key-file /etc/luks/photos_keyfile.bin /dev/disk/by-uuid/bf5cafa1-f081-4005-b4f6-8fd0a3c3c109 videos
#notify-send "Media disk decryption" "Videos have been decrypted" --icon=dialog-information

echo "Mounting all drives"
mount -a
echo "Done!"
#notify-send "Media disk decryption" "Media disks remounted!" --icon=dialog-information


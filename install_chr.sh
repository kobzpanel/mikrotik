#!/bin/bash
set -e

# === Settings ===
DISK="/dev/sda"              # Adjust if your VPS uses another disk
CHR_VERSION="7.15.3"         # Change if newer version available
CHR_URL="https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip"

echo "[+] Downloading MikroTik CHR ${CHR_VERSION} image..."
curl -L "$CHR_URL" -o /tmp/chr.img.zip

echo "[+] Unzipping image..."
funzip /tmp/chr.img.zip > /tmp/chr.img

echo "[+] Writing image to $DISK (this will wipe ALL data!)"
dd if=/tmp/chr.img of=$DISK bs=1M conv=fsync status=progress

echo "[+] Syncing disk writes..."
sync

echo "[+] Cleaning up..."
rm -f /tmp/chr.img /tmp/chr.img.zip

echo "[+] Installation done. Rebooting..."
reboot

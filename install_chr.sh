#!/bin/bash
set -e

# Settings — adjust as needed
DISK="/dev/sda"                     # Target disk; wipe everything there
CHR_VERSION="7.15.3"                # RouterOS CHR version—update if a newer one exists
CHR_URL="https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip"

echo "[+] Downloading MikroTik CHR ${CHR_VERSION} image..."
curl -L "$CHR_URL" -o /tmp/chr.img.zip

echo "[+] Extracting image..."
funzip /tmp/chr.img.zip > /tmp/chr.img

echo "[+] Writing image to $DISK (wipes ALL data!)"
dd if=/tmp/chr.img of="$DISK" bs=1M conv=fsync status=progress

echo "[+] Syncing disk writes..."
sync

echo "[+] Cleaning up temporary files..."
rm -f /tmp/chr.img /tmp/chr.img.zip

echo "[+] Installation complete. Rebooting..."
reboot

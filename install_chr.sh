#!/bin/bash -e

echo
echo "=== AL AMIN ==="
echo "=== https://facebook.com/alaminbd17 ==="
echo "=== MikroTik CHR Installer ==="
echo "=== Supports: Ubuntu, Debian, CentOS, Rocky Linux, AlmaLinux, Amazon Linux ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Detect OS and install required packages
detect_os_and_install_deps() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                echo "Detected Debian-based system"
                apt-get update
                apt-get install -y wget curl gunzip lsblk iproute2
                ;;
            centos|rocky|almalinux|rhel)
                echo "Detected RHEL-based system"
                yum install -y wget curl gunzip util-linux iproute
                ;;
            amzn)
                echo "Detected Amazon Linux"
                yum install -y wget curl gunzip util-linux iproute
                ;;
            *)
                echo "Unsupported OS: $ID"
                echo "Trying to continue with basic tools..."
                ;;
        esac
    else
        echo "Cannot detect OS type. Trying to continue..."
    fi
}

# Function to get network interface
get_network_interface() {
    # Try multiple methods to get the default network interface
    if command -v ip >/dev/null 2>&1; then
        ETH=$(ip route show default | sed -n 's/.* dev \([^ ]*\) .*/\1/p' 2>/dev/null | head -n1)
    fi
    
    # Fallback methods
    if [ -z "$ETH" ]; then
        if command -v route >/dev/null 2>&1; then
            ETH=$(route -n | grep '^0\.0\.0\.0' | grep -v 'UG.*tun' | head -n1 | awk '{print $8}')
        fi
    fi
    
    if [ -z "$ETH" ]; then
        # Last resort - get first non-loopback interface
        ETH=$(ls /sys/class/net/ | grep -v lo | head -n1)
    fi
    
    echo "$ETH"
}

# Function to get storage device
get_storage_device() {
    # Try multiple methods to find the main storage device
    if command -v lsblk >/dev/null 2>&1; then
        STORAGE=$(lsblk -nd -o NAME,TYPE | grep 'disk' | awk '{print $1}' | head -n1)
    elif [ -b /dev/vda ]; then
        STORAGE="vda"
    elif [ -b /dev/sda ]; then
        STORAGE="sda"
    elif [ -b /dev/xvda ]; then
        STORAGE="xvda"
    else
        # Last resort - get first disk device
        STORAGE=$(ls /dev/sd? /dev/vd? /dev/xvd? 2>/dev/null | head -n1 | sed 's|/dev/||')
    fi
    
    echo "$STORAGE"
}

# Function to validate network information
validate_network_info() {
    if [ -z "$ETH" ]; then
        echo "ERROR: Could not detect network interface"
        exit 1
    fi
    
    if [ -z "$ADDRESS" ]; then
        echo "WARNING: Could not detect IP address"
    fi
    
    if [ -z "$GATEWAY" ]; then
        echo "WARNING: Could not detect gateway"
    fi
}

# Function to download CHR image
download_chr() {
    local version="7.10"
    local url="https://download.mikrotik.com/routeros/${version}/chr-${version}.img.zip"
    local retries=3
    local count=0
    
    while [ $count -lt $retries ]; do
        echo "Downloading MikroTik CHR ${version} (attempt $((count+1))/$retries)..."
        if wget --timeout=30 --tries=3 -O chr.img.zip "$url"; then
            echo "Download completed successfully"
            return 0
        fi
        count=$((count+1))
        echo "Download failed, retrying in 5 seconds..."
        sleep 5
    done
    
    echo "ERROR: Failed to download CHR image after $retries attempts"
    exit 1
}

echo "Starting installation process..."
sleep 3

# Install dependencies
echo "Installing required dependencies..."
detect_os_and_install_deps

# Get system information
echo "Detecting system configuration..."
ETH=$(get_network_interface)
STORAGE=$(get_storage_device)

# Get network information
if command -v ip >/dev/null 2>&1; then
    ADDRESS=$(ip addr show "$ETH" 2>/dev/null | grep -oP 'inet \K[\d./]+' | head -n1)
    GATEWAY=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)
fi

# Display detected information
echo "=== System Information ==="
echo "Storage device: $STORAGE"
echo "Network interface: $ETH"
echo "IP address: $ADDRESS"
echo "Gateway: $GATEWAY"
echo

# Validate network information
validate_network_info

echo "Proceeding with installation in 10 seconds..."
echo "WARNING: This will overwrite the entire disk ($STORAGE) and destroy all data!"
echo "Press Ctrl+C to cancel now!"
sleep 10

# Download and prepare CHR image
echo "Downloading MikroTik CHR image..."
download_chr

echo "Extracting image..."
if ! gunzip -c chr.img.zip > chr.img 2>/dev/null; then
    echo "ERROR: Failed to extract image file"
    echo "Trying alternative extraction method..."
    if command -v unzip >/dev/null 2>&1; then
        unzip -o chr.img.zip
    else
        echo "Please install unzip or gunzip and try again"
        exit 1
    fi
fi

# Verify the image file exists
if [ ! -f chr.img ]; then
    echo "ERROR: chr.img not found after extraction"
    exit 1
fi

# Get image size
IMAGE_SIZE=$(stat -c%s chr.img 2>/dev/null || stat -f%z chr.img 2>/dev/null)
if [ -z "$IMAGE_SIZE" ] || [ "$IMAGE_SIZE" -lt 1000000 ]; then
    echo "ERROR: Image file appears to be too small or invalid"
    exit 1
fi

echo "Image size: $((IMAGE_SIZE/1024/1024)) MB"

# Write image to disk
echo "Writing image to /dev/$STORAGE (this may take several minutes)..."
if ! dd if=chr.img of="/dev/$STORAGE" bs=4M status=progress oflag=sync; then
    echo "ERROR: Failed to write image to disk"
    exit 1
fi

echo "Syncing disks..."
sync

# Final instructions
echo
echo "=== Installation Completed Successfully! ==="
echo
echo "Important notes:"
echo "1. The system will now reboot into MikroTik CHR"
echo "2. After reboot, connect to the console to configure"
echo "3. Default username: admin (no password)"
echo "4. Configure your IP address:"
echo "   /ip address add address=$ADDRESS interface=ether1"
echo "5. Add default route:"
echo "   /ip route add gateway=$GATEWAY"
echo
echo "Rebooting in 10 seconds..."
sleep 10

# Reboot system
echo "Initiating reboot..."
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger

#!/bin/bash
set -euo pipefail

# --- Config (overrides allowed via env) ---
CHR_VERSION="${CHR_VERSION:-7.20}"
CHR_URL="https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip"
DISK="${DISK:-}"           # If empty, auto-detect
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"  # Set to 1 to skip confirm prompt

TMP_ZIP="chr.img.zip"
TMP_IMG="chr.img"

say() { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

auto_detect_disk() {
  if ! command -v lsblk >/dev/null 2>&1; then
    echo ""
    return 0
  fi
  # Pick the largest physical disk with TYPE=disk (ignore loop/rom)
  local picked
  picked=$(lsblk -dn -o NAME,TYPE,SIZE 2>/dev/null | awk '$2=="disk"{print $0}' | sort -k3 -hr | head -1 | awk '{print $1}')
  [[ -n "$picked" ]] && echo "/dev/$picked" || echo ""
}

check_disk_exists() {
  if command -v lsblk >/dev/null 2>&1; then
    lsblk -dn | awk '{print "/dev/"$1}' | grep -qx "$DISK"
  else
    # Fallback: check if block device
    test -b "$DISK"
  fi
}

confirm_or_exit() {
  [[ "$NON_INTERACTIVE" = "1" ]] && return 0
  warn "This will ERASE ALL DATA on $DISK. Type 'YES' to continue:"
  read -r ans
  [[ "$ans" = "YES" ]] || { err "Aborted."; exit 1; }
}

detect_network() {
  local eth gateway address
  if ! command -v ip >/dev/null 2>&1; then
    err "ip command not found. Cannot detect network config."
    exit 1
  fi
  eth=$(ip route show default 2>/dev/null | sed -n 's/.* dev \([^\ ]*\) .*/\1/p' | head -1)
  [[ -n "$eth" ]] || { err "Default route not found."; exit 1; }
  say "Detected interface: $eth"
  address=$(ip addr show "$eth" 2>/dev/null | awk '/scope global/ {print $2; exit}')
  [[ -n "$address" ]] && say "Detected address: $address" || warn "No global IP on $eth"
  gateway=$(ip route | grep '^default' | awk '{print $3}' | head -1)
  [[ -n "$gateway" ]] && say "Detected gateway: $gateway" || warn "No default gateway found"
  echo "After reboot into CHR (default login: admin, no password):"
  echo "  /ip address add address=$address interface=$eth"
  if [[ -n "$gateway" ]]; then
    echo "  /ip route add dst-address=0.0.0.0/0 gateway=$gateway"
  fi
  echo "Then /system reboot to apply."
}

download_img() {
  say "Downloading CHR image..."
  if command -v wget >/dev/null 2>&1; then
    wget -O "$TMP_ZIP" "$CHR_URL"
  elif command -v curl >/dev/null 2>&1; then
    curl -fL -o "$TMP_ZIP" "$CHR_URL"
  else
    err "Neither wget nor curl found. Please install one."
    exit 1
  fi
}

extract_img() {
  say "Extracting image..."
  if command -v unzip >/dev/null 2>&1; then
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  fi
  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -O -xf "$TMP_ZIP" > "$TMP_IMG" && return 0
  fi
  if command -v 7z >/dev/null 2>&1; then
    7z e -so "$TMP_ZIP" > "$TMP_IMG" && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import zipfile
import sys
zip_path = "chr.img.zip"
out_path = "chr.img"
try:
    with zipfile.ZipFile(zip_path) as zf:
        name = zf.namelist()[0]
        with zf.open(name) as src, open(out_path, "wb") as dst:
            dst.write(src.read())
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PY
    return 0
  fi
  # Install unzip if possible
  if command -v apt-get >/dev/null 2>&1; then
    say "Installing unzip (Debian/Ubuntu)..."
    apt-get update -qq && apt-get install -y unzip >/dev/null
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  elif command -v yum >/dev/null 2>&1; then
    say "Installing unzip (RHEL/CentOS 7)..."
    yum install -y unzip >/dev/null 2>&1
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  elif command -v dnf >/dev/null 2>&1; then
    say "Installing unzip (Fedora/RHEL 8+)..."
    dnf install -y unzip >/dev/null 2>&1
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  elif command -v apk >/dev/null 2>&1; then
    say "Installing unzip (Alpine)..."
    apk add --no-cache unzip >/dev/null 2>&1
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  elif command -v pacman >/dev/null 2>&1; then
    say "Installing unzip (Arch)..."
    pacman -S --noconfirm unzip >/dev/null 2>&1
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  elif command -v zypper >/dev/null 2>&1; then
    say "Installing unzip (openSUSE)..."
    zypper --non-interactive install unzip >/dev/null 2>&1
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  fi
  err "Failed to extract ZIP (no suitable tool and couldn't install unzip)."
  return 1
}

# --- Main ---
echo
echo "=== AL AMIN ==="
echo "
    _    _          _    __  __ ___ _   _ 
   / \  | |        / \  |  \/  |_ _| \ | |
  / _ \ | |       / _ \ | |\/| || ||  \| |
 / ___ \| |___   / ___ \| |  | || || |\  |
/_/   \_\_____| /_/   \_\_|  |_|___|_| \_|                                                                                
"
echo "***** https://facebook.com/alaminbd17 *****"

echo "=== MikroTik CHR Installer (version $CHR_VERSION) ==="
echo
sleep 3

if [[ -z "${DISK}" ]]; then
  DISK="$(auto_detect_disk)"
  [[ -n "$DISK" ]] || { err "No target disk found. Set DISK env var (e.g., /dev/sda)." && exit 1; }
  say "Auto-detected disk: $DISK"
fi

# sanity check disk exists
if ! check_disk_exists; then
  err "Disk $DISK not found or not a block device."
  exit 1
fi

confirm_or_exit

detect_network

download_img

if ! extract_img; then
  exit 1
fi

say "Writing image to $DISK (this will erase everything)..."
dd if="$TMP_IMG" of="$DISK" bs=4M oflag=sync status=progress

say "Flushing writes..."
sync

say "Cleaning up..."
rm -f "$TMP_IMG" "$TMP_ZIP"

say "Done. Rebooting into MikroTik CHR..."
if command -v reboot >/dev/null 2>&1; then
  reboot -f
else
  echo 1 > /proc/sys/kernel/sysrq
  echo b > /proc/sysrq-trigger
fi

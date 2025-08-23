#!/bin/bash
set -euo pipefail

# ==== Config ====
DISK="${DISK:-/dev/sda}"              # WARNING: will be wiped
CHR_VERSION="${CHR_VERSION:-7.15.3}"  # Change if you want a newer version
CHR_URL="https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip"

TMP_ZIP="/tmp/chr.img.zip"
TMP_IMG="/tmp/chr.img"

echo "[+] Target disk: $DISK"
if ! lsblk -dn | grep -q "$(basename "$DISK")"; then
  echo "[!] Disk $DISK not found. Aborting."
  exit 1
fi

echo "[+] Downloading MikroTik CHR $CHR_VERSION ..."
curl -fL "$CHR_URL" -o "$TMP_ZIP"

extract_img() {
  echo "[+] Extracting image..."
  if command -v funzip >/dev/null 2>&1; then
    funzip "$TMP_ZIP" > "$TMP_IMG" && return 0
  fi
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
import zipfile, sys
zip_path = "/tmp/chr.img.zip"
out_path = "/tmp/chr.img"
with zipfile.ZipFile(zip_path) as zf:
    # Take the first entry (the .img)
    name = zf.namelist()[0]
    with zf.open(name) as src, open(out_path, "wb") as dst:
        dst.write(src.read())
PY
    return 0
  fi
  # Last resort: try to install unzip if apt-get is present (Debian/Ubuntu rescue)
  if command -v apt-get >/dev/null 2>&1; then
    echo "[+] Installing unzip..."
    apt-get update -y && apt-get install -y unzip
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  fi
  return 1
}

if ! extract_img; then
  echo "[!] Could not extract ZIP (no funzip/unzip/bsdtar/7z/python3 and apt-get unavailable)."
  exit 1
fi

echo "[+] Writing image to $DISK (this will erase ALL data)..."
# Use pv if available for nicer progress; otherwise fall back to dd status=progress
if command -v pv >/dev/null 2>&1; then
  pv "$TMP_IMG" | dd of="$DISK" bs=1M conv=fsync status=progress
else
  dd if="$TMP_IMG" of="$DISK" bs=1M conv=fsync status=progress
fi

echo "[+] Flushing writes..."
sync

echo "[+] Cleaning up..."
rm -f "$TMP_IMG" "$TMP_ZIP"

echo "[+] Done. Rebooting into MikroTik CHR..."
reboot

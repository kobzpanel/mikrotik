#!/bin/bash
set -euo pipefail

# --- Config (overrides allowed via env) ---
CHR_VERSION="${CHR_VERSION:-7.15.3}"
CHR_URL="https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip"
DISK="${DISK:-}"           # If empty, auto-detect
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"  # Set to 1 to skip confirm prompt

TMP_ZIP="/tmp/chr.img.zip"
TMP_IMG="/tmp/chr.img"

say() { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
err() { echo -e "\033[1;31m[x]\033[0m $*" >&2; }

auto_detect_disk() {
  # Pick the largest physical disk with TYPE=disk (ignore loop/rom)
  # Works for sda/vda/nvme0n1, etc.
  local picked
  picked=$(lsblk -dn -o NAME,TYPE,SIZE | awk '$2=="disk"{print $0}' | sort -k3 -h | tail -1 | awk '{print $1}')
  [[ -n "$picked" ]] && echo "/dev/$picked" || echo ""
}

confirm_or_exit() {
  [[ "$NON_INTERACTIVE" = "1" ]] && return 0
  warn "This will ERASE ALL DATA on $DISK. Type 'YES' to continue:"
  read -r ans
  [[ "$ans" = "YES" ]] || { err "Aborted."; exit 1; }
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
zip_path = "/tmp/chr.img.zip"
out_path = "/tmp/chr.img"
with zipfile.ZipFile(zip_path) as zf:
    # pick first file (the .img)
    name = zf.namelist()[0]
    with zf.open(name) as src, open(out_path, "wb") as dst:
        dst.write(src.read())
PY
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    say "Installing unzip..."
    apt-get update -y && apt-get install -y unzip >/dev/null
    unzip -p "$TMP_ZIP" > "$TMP_IMG" && return 0
  fi
  return 1
}

# --- Main ---
say "MikroTik CHR installer (version $CHR_VERSION)"

if [[ -z "${DISK}" ]]; then
  DISK="$(auto_detect_disk)"
  [[ -n "$DISK" ]] || { err "No target disk found."; exit 1; }
  say "Auto-detected disk: $DISK"
fi

# sanity check disk exists
if ! lsblk -dn | awk '{print "/dev/"$1}' | grep -qx "$DISK"; then
  err "Disk $DISK not found in lsblk output."
  exit 1
fi

confirm_or_exit

say "Downloading CHR image..."
curl -fL "$CHR_URL" -o "$TMP_ZIP"

if ! extract_img; then
  err "Failed to extract ZIP (no unzip/bsdtar/7z/python3 and can't install)."
  exit 1
fi

say "Writing image to $DISK (this will erase everything)..."
if command -v pv >/dev/null 2>&1; then
  pv "$TMP_IMG" | dd of="$DISK" bs=1M conv=fsync status=progress
else
  dd if="$TMP_IMG" of="$DISK" bs=1M conv=fsync status=progress
fi

say "Flushing writes..."
sync

say "Cleaning up..."
rm -f "$TMP_IMG" "$TMP_ZIP"

say "Done. Rebooting into MikroTik CHR..."
reboot

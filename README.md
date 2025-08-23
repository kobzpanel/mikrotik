# MikroTik CHR Auto-Installer (Hetzner Rescue Mode)

This repository contains a simple shell script to **clean install MikroTik Cloud Hosted Router (CHR)** on a VPS such as Hetzner.  
It wipes the server’s primary disk, flashes a fresh MikroTik RouterOS CHR image, and reboots.

---

## ⚠️ Warning

- This script will **ERASE ALL DATA** on the specified disk (default: auto-detected `/dev/sda`, `/dev/vda`, or `/dev/nvme0n1`).
- Use only in **Hetzner Rescue Mode** or a similar rescue/live system.
- Double-check the target disk before running.

---

## Quick One-Liner

Run directly from Hetzner Rescue (Linux64):

```bash
NON_INTERACTIVE=1 bash <(curl -fsSL https://raw.githubusercontent.com/kobzpanel/mikrotik/refs/heads/main/install_chr.sh)


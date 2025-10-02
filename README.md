# MikroTik CHR Auto-Installer

A robust Bash script for installing MikroTik's Cloud Hosted Router (CHR) on any cloud VM or VPS provider.

## 📋 Overview

This script automates the installation of MikroTik CHR (RouterOS) on virtual private servers across various cloud providers and Linux distributions. It handles OS detection, dependency installation, and provides a seamless installation experience.

## ✨ Features

- **Multi-OS Support**: Ubuntu, Debian, CentOS, Rocky Linux, AlmaLinux, Amazon Linux
- **Cloud Provider Compatibility**: AWS, DigitalOcean, Vultr, Linode, Google Cloud, Azure, and more
- **Automatic Detection**: Smart detection of storage devices and network interfaces
- **Error Handling**: Comprehensive validation and meaningful error messages
- **Safety Features**: Clear warnings and confirmation prompts
- **Post-Install Guidance**: Helpful configuration instructions after installation

## 🚀 Quick Start

### Prerequisites

- A cloud VPS/Virtual Machine
- Root/sudo access
- Internet connectivity
- Minimum 512MB RAM, 1GB disk space

### Installation

1. **Download the script**:
```bash
wget -O install-chr.sh https://raw.githubusercontent.com/kobzpanel/mikrotik/refs/heads/main/install_chr.sh
chmod +x install_chr.sh
```

```bash
  bash -c "$(curl -L https://raw.githubusercontent.com/kobzpanel/mikrotik/refs/heads/main/install_chr.sh)"
```


# MikroTik CHR Login Guide

Complete guide on how to access and log into your MikroTik CHR after installation.

## 🌐 Access Methods

### 1. Web Interface (WinBox/WebFig)
### 2. SSH Console
### 3. Serial Console (VPS Provider)

---

## 🔗 Method 1: Web Interface Login

### Default Web Access
- **URL**: `http://YOUR_VPS_IP`
- **Port**: 80 (HTTP)
- **Username**: `admin`
- **Password**: *[blank initially]*


# Example:
http://192.168.1.100


📄 License
MIT License

🙏 Acknowledgments
MikroTik for CHR and RouterOS

Cloud providers supporting custom images

Open source community

Maintainer: Al Amin
Contact: https://facebook.com/alaminbd17
Last Updated: 2024



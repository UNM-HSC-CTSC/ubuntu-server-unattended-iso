# Minimal Server Profile

Absolute minimum Ubuntu Server installation with only essential packages.

## Overview

This profile creates the smallest possible Ubuntu Server installation while maintaining:
- Network connectivity
- SSH access
- Basic system tools

## Configuration

- **Hostname**: ubuntu-minimal
- **Username**: ubuntu
- **Password**: ubuntu (CHANGE THIS!)
- **Network**: DHCP
- **Storage**: LVM
- **SSH**: Enabled with password authentication

## Installed Packages

- openssh-server - Remote access
- curl - URL data transfer
- wget - Network downloader
- nano - Text editor
- net-tools - Network utilities
- iputils-ping - Network diagnostics

## Optimizations

- Snap packages removed
- Multipath disabled
- Minimal service footprint
- No automatic updates

## Use Cases

- Container/Docker hosts
- Embedded systems
- Resource-constrained VMs
- Base for custom installations
- Testing environments

## Resource Requirements

- **RAM**: 512MB minimum (1GB recommended)
- **Storage**: 2GB minimum
- **CPU**: 1 core

## Post-Installation

After installation:
1. Change the default password
2. Configure static IP if needed
3. Install only required packages
4. Enable firewall if exposed to network

## Building ISO

```bash
./build-iso.sh --profile minimal-server
```

## Notes

This profile prioritizes minimal footprint over features. For production servers, consider the standard-server or security-hardened profiles.
# Standard Server Profile

A well-balanced Ubuntu Server installation with common tools, monitoring, and security configurations.

## Overview

This profile creates a production-ready server with:
- Comprehensive system utilities
- Security hardening
- Monitoring tools
- Automatic updates
- Firewall configuration

## Configuration

- **Hostname**: ubuntu-server
- **Username**: sysadmin
- **Password**: ChangeMeNow! (MUST BE CHANGED!)
- **Network**: DHCP
- **Storage**: LVM
- **SSH**: Key-based authentication only (password auth disabled)
- **Timezone**: America/New_York

## Security Features

### SSH Hardening
- Password authentication disabled
- Root login disabled
- Key-based authentication required

### Firewall (UFW)
- Enabled by default
- Default deny incoming
- SSH allowed

### Fail2ban
- Monitors SSH attempts
- 5 attempts = 1-hour ban

### System Hardening
- Kernel parameters tuned for security
- Root account locked
- Automatic security updates enabled

## Installed Packages

### System Utilities
- htop, iotop, iftop - Process and I/O monitoring
- tmux, screen - Terminal multiplexers
- vim, emacs-nox - Text editors
- ncdu - Disk usage analyzer

### Network Tools
- nmap - Network scanner
- tcpdump - Packet analyzer
- mtr - Network diagnostic
- dnsutils - DNS utilities

### Development Tools
- git - Version control
- build-essential - Compilers
- python3-pip - Python package manager

### Security Tools
- fail2ban - Intrusion prevention
- ufw - Firewall
- aide - File integrity
- apparmor-utils - MAC utilities

### Monitoring
- sysstat - System statistics
- smartmontools - Disk health
- logwatch - Log analysis

## Resource Requirements

- **RAM**: 2GB minimum (4GB recommended)
- **Storage**: 8GB minimum (20GB recommended)
- **CPU**: 2 cores recommended

## Post-Installation Steps

### Required
1. **Add SSH Key**: Replace placeholder in autoinstall.yaml
2. **Change Password**: Set a strong password
3. **Update System**: `sudo apt update && sudo apt upgrade`

### Recommended
1. Configure static IP if needed
2. Set up monitoring alerts
3. Configure backup solution
4. Review and adjust firewall rules
5. Set up log shipping/centralization

## Use Cases

- General-purpose servers
- Web application hosts
- Development servers
- Small business servers
- Home lab servers

## Building ISO

```bash
# First, add your SSH public key to the autoinstall.yaml
nano profiles/standard-server/autoinstall.yaml

# Then build the ISO
./build-iso.sh --profile standard-server
```

## Customization

To customize this profile:
1. Adjust package list based on needs
2. Modify security settings
3. Add custom late-commands
4. Change network configuration
5. Adjust storage layout

## Notes

- SSH key must be added before building ISO
- First boot may take longer due to package installation
- Security updates will install automatically
- System will not auto-reboot for kernel updates
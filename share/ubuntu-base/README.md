# Ubuntu Base Configuration

This is the minimal base configuration for Ubuntu Server unattended installation.

## Features

- Basic DHCP networking
- LVM storage layout
- SSH server enabled
- Essential system packages
- System updates enabled

## Important Notes

1. **Change default credentials** - The default username is `ubuntu` with password `ubuntu`. You MUST change these before use.

2. **Generate secure passwords**:
   ```bash
   openssl passwd -6 -stdin <<< "your-secure-password"
   ```

3. **Add SSH keys** - Uncomment and add your SSH public keys in the `late-commands` section for secure access.

4. **Network interface** - The configuration assumes `eth0`. Adjust based on your hardware.

## Usage

Use this as a starting point with the interactive generator:

```bash
ubuntu-iso-generate
```

Or use directly with the build command:

```bash
ubuntu-iso --autoinstall share/ubuntu-base/autoinstall.yaml
```
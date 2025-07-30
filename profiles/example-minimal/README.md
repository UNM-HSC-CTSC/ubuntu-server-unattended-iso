# Example Minimal Profile

A minimal Ubuntu Server installation with basic tools and SSH access.

## Configuration

- **Hostname**: ubuntu-server
- **Username**: ubuntu
- **Password**: ubuntu (change after installation!)
- **Network**: DHCP
- **Storage**: LVM without encryption
- **Timezone**: UTC

## Installed Packages

- curl
- wget
- vim
- htop
- net-tools
- openssh-server

## Usage

Build an ISO with this profile:

```bash
./build-iso.sh --profile example-minimal
```

## Security Note

This profile uses a default password for demonstration purposes. Always change the password after installation or use SSH key authentication in production environments.
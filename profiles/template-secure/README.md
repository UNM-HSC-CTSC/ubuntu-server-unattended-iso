# Template Secure Profile

A security-hardened Ubuntu Server template that uses environment variables for credentials during ISO build time. This ensures no sensitive data is stored in the repository.

## Overview

This profile creates a secure Ubuntu Server installation with:
- SSH key-only authentication (no password SSH)
- Disabled root SSH login
- UFW firewall enabled
- User account with sudo access
- Minimal package installation
- Security hardening applied

## Required Environment Variables

Before building an ISO with this profile, you must set the following environment variables:

- `DEFAULT_USERNAME` - Username for the default user account
- `DEFAULT_USER_PASSWORD` - Password for the default user (console access only)
- `DEFAULT_USER_SSH_KEY` - SSH public key for the default user
- `ROOT_PASSWORD` - Root account password (SSH disabled)

### Password Requirements

Passwords must meet the following complexity requirements:
- Minimum 12 characters long
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

### Username Requirements

- Must start with a lowercase letter
- Can contain lowercase letters, numbers, underscore, dash
- Maximum 32 characters

## Usage

### Command Line Build

```bash
# Set credentials
export DEFAULT_USERNAME="myuser"
export DEFAULT_USER_PASSWORD="MySecureP@ssw0rd123!"
export DEFAULT_USER_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@example.com"
export ROOT_PASSWORD="R00tP@ssw0rd456!"

# Build the ISO
./build-iso.sh --profile template-secure
```

### GitLab CI/CD

Configure the following as protected/masked variables in GitLab:
- `DEFAULT_USERNAME` (protected)
- `DEFAULT_USER_PASSWORD` (masked)
- `DEFAULT_USER_SSH_KEY` (protected)
- `ROOT_PASSWORD` (masked)

Then trigger the build manually or set `BUILD_SECURE_TEMPLATE=true`.

## Security Features

### SSH Configuration
- `PermitRootLogin no` - Root cannot SSH
- `PasswordAuthentication no` - SSH key required
- `PubkeyAuthentication yes` - Public key auth enabled
- `MaxAuthTries 3` - Limit authentication attempts
- `ClientAliveInterval 120` - Disconnect idle sessions

### Firewall
- UFW enabled by default
- Default deny incoming
- Default allow outgoing
- SSH (port 22) allowed

### Account Security
- Root account has password but cannot SSH
- Default user in sudo group
- Installer account removed after installation
- Home directories have 700 permissions

## Access Methods

### SSH Access
```bash
ssh -i ~/.ssh/your_private_key username@server_ip
```

### Console Access
Use the username and password for physical or console access.

### Root Access
```bash
# From user account
sudo -i
# Enter user password
```

## Post-Installation

After installation, consider:

1. **Change passwords immediately**
   ```bash
   passwd              # Change user password
   sudo passwd root    # Change root password
   ```

2. **Add additional SSH keys**
   ```bash
   echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys
   ```

3. **Configure additional firewall rules**
   ```bash
   sudo ufw allow 80/tcp   # HTTP
   sudo ufw allow 443/tcp  # HTTPS
   ```

4. **Install security updates**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Credential Security

This profile ensures:
- No credentials stored in repository
- Credentials injected only during build
- All temporary files securely deleted
- Environment variables cleared after build
- Build artifacts (ISOs) contain hashed passwords only

## Troubleshooting

### Build Failures

If the build fails with credential errors:
1. Ensure all 4 environment variables are set
2. Check password complexity requirements
3. Verify SSH key format (ssh-rsa, ssh-ed25519, or ssh-ecdsa)
4. Ensure username meets requirements

### Access Issues

If you cannot access the server:
1. Verify SSH key matches the one provided during build
2. Check firewall isn't blocking SSH (port 22)
3. Use console access with username/password
4. Check `/var/log/auth.log` for authentication errors

## Example Credentials (DO NOT USE IN PRODUCTION)

```bash
export DEFAULT_USERNAME="ubuntu"
export DEFAULT_USER_PASSWORD="UbuntuP@ssw0rd123!"
export DEFAULT_USER_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPvLZG6WK6yk5pPl0xXnPHvzM3G9Wg/oKW9K example@ubuntu"
export ROOT_PASSWORD="R00tUbuntuP@ss456!"
```
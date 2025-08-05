# GitHub Server Profile

This profile creates a GitHub/Gitea server using role-based configuration with cloud-init metadata.

## Overview

Creates a Git repository server with:
- Gitea web interface
- PostgreSQL database
- Git LFS support
- CI/CD webhook integration
- Automated backups

## How It Works

1. **Boot**: Server boots with this ISO
2. **Cloud-Init**: Reads embedded role metadata
3. **Bootstrap**: Contacts config server and identifies as "github" role
4. **Ansible**: Pulls and executes GitHub role configuration
5. **Result**: Fully configured Git server

## Metadata Configuration

The ISO embeds the following metadata:
```yaml
metadata:
  role: github
  environment: production
  config_server: hsc-ctsc-config.health.unm.edu
```

## Network Configuration

- **Initial Hostname**: Set dynamically based on role
- **Final Hostname**: `hsc-ctsc-github-{instance}`
- **IP Assignment**: DHCP from F5 BIG-IP
- **DNS**: Automatically registered

## Default Credentials

- **System User**: `sysadmin` / `ChangeMe123!`
- **Gitea Admin**: Created by Ansible role
- **Database**: Managed by Ansible

## Post-Deployment

The server will:
1. Contact config server
2. Download Ansible playbooks
3. Configure all services
4. Create users from config
5. Set up scheduled backups

## Verification

Check deployment status:
```bash
# SSH to server
ssh sysadmin@hsc-ctsc-github-01

# Check bootstrap status
systemctl status bootstrap-role
journalctl -u bootstrap-role

# Verify services (after Ansible completes)
systemctl status gitea
systemctl status postgresql
systemctl status nginx
```

## Customization

To use different settings, modify the metadata in the ISO:
```bash
# Build with custom metadata
./bin/ubuntu-iso \
  --role github \
  --metadata "environment=staging" \
  --metadata "config_server=config.example.com"
```

## Troubleshooting

### Bootstrap Fails
```bash
# Check cloud-init metadata
cloud-init query -a

# Check network connectivity
ping hsc-ctsc-config.health.unm.edu

# Run bootstrap manually
sudo /usr/local/bin/bootstrap-role.sh
```

### Can't Access Gitea
- Wait for Ansible to complete (5-10 minutes)
- Check nginx is running
- Verify firewall rules

## Related Documentation

- [Role Definitions](../../docs/ROLE-DEFINITIONS.md#github-server)
- [Deployment Guide](../../docs/DEPLOYMENT-GUIDE.md)
- [Ansible GitHub Role](../../ansible/roles/github/)
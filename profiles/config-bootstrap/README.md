# Config Server Bootstrap Profile

This profile creates a self-contained configuration server that serves as the foundation for all other server deployments in the HSC-CTSC infrastructure.

## Overview

The config server provides:
- Ansible playbook hosting via Git
- Configuration file serving via HTTP/HTTPS
- Role definitions and mappings
- Bootstrap scripts for other servers

## Key Features

- **Self-Contained**: No external dependencies required
- **Git Server**: Hosts Ansible configurations via Git HTTP backend
- **Web Interface**: Browse configurations via web browser
- **Health Checks**: Built-in health monitoring endpoint
- **Secure**: Firewall enabled with minimal exposed ports

## Network Configuration

- **Hostname**: `hsc-ctsc-config` (FQDN: `hsc-ctsc-config.health.unm.edu`)
- **IP Assignment**: DHCP from F5 BIG-IP
- **Ports**:
  - 22 (SSH)
  - 80 (HTTP)
  - 443 (HTTPS)
  - 9418 (Git)
  - 9100 (Node Exporter)

## Default Credentials

- **Username**: `configadmin`
- **Password**: `ChangeMe123!` (MUST be changed on first login)

## Storage Requirements

- **Minimum**: 20GB
- **Recommended**: 50GB
- **Partitions**:
  - `/boot`: 1GB
  - `/`: Remaining space

## Post-Installation Steps

1. **Change Default Password**:
   ```bash
   ssh configadmin@hsc-ctsc-config.health.unm.edu
   passwd
   ```

2. **Initialize Ansible Repository**:
   ```bash
   # From your workstation
   git clone http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
   cd ansible-config
   # Copy your Ansible playbooks here
   git add .
   git commit -m "Initial Ansible configuration"
   git push origin main
   ```

3. **Configure SSL Certificate** (optional):
   ```bash
   # Install Let's Encrypt certificate
   sudo certbot --nginx -d hsc-ctsc-config.health.unm.edu
   ```

4. **Verify Services**:
   ```bash
   sudo /usr/local/bin/config-server-status
   ```

## Directory Structure

```
/var/www/config/
├── ansible/          # Ansible playbooks and roles
├── roles/            # Server role definitions
├── scripts/          # Bootstrap and utility scripts
├── git/              # Git repositories
│   └── ansible-config.git
├── index.html        # Web interface home page
├── .bootstrap-complete    # Bootstrap completion marker
└── .bootstrap-timestamp   # Bootstrap timestamp
```

## Accessing the Config Server

### Web Interface
- http://hsc-ctsc-config.health.unm.edu
- https://hsc-ctsc-config.health.unm.edu

### Git Repository
```bash
git clone http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
```

### Health Check
```bash
curl http://hsc-ctsc-config.health.unm.edu/health
```

## Security Considerations

1. **Change default password immediately**
2. **Configure SSL certificates for HTTPS**
3. **Restrict SSH access to known IP ranges if possible**
4. **Regular security updates are configured automatically**
5. **Monitor logs in `/var/log/nginx/` and `/var/log/auth.log`

## Troubleshooting

### Check Service Status
```bash
sudo systemctl status nginx
sudo systemctl status git-daemon
sudo systemctl status ssh
```

### View Logs
```bash
sudo journalctl -u nginx
sudo journalctl -u git-daemon
sudo tail -f /var/log/nginx/error.log
```

### Test Git Access
```bash
git ls-remote http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
```

## Related Documentation

- [Bootstrap Guide](../../docs/BOOTSTRAP-GUIDE.md)
- [Architecture Overview](../../docs/ARCHITECTURE.md)
- [Role Definitions](../../docs/ROLE-DEFINITIONS.md)
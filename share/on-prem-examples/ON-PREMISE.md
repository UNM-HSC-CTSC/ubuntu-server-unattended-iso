# On-Premise Bootstrap System

This directory contains a complete example of an on-premise server bootstrapping system using cloud-init and Ansible. The system allows newly provisioned servers to automatically configure themselves based on their assigned roles without requiring a central Ansible server.

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   DHCP Server   │────▶│  New VM Boots    │────▶│  DNS Resolves   │
│ (Assigns IP)    │     │  (PXE/ISO Boot)  │     │ config.internal │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │                           │
                                ▼                           ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Cloud-Init Runs │◀────│ Ansible-Pull     │◀────│ Config Server   │
│ Bootstrap Script│     │ Applies Roles    │     │ (HTTP/Git)      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Prerequisites

For this system to work, you need the following infrastructure:

1. **DHCP Server**: Assigns IP addresses to new VMs
2. **DNS Server**: Resolves `config.internal.company.com` to your configuration server
3. **Configuration Server**: Hosts role mappings, user data, and Ansible playbooks
4. **Ubuntu ISO Builder**: Creates bootstrap ISOs with the minimal autoinstall configuration

## Components

### 1. Bootstrap Autoinstall (`bootstrap-autoinstall.yaml`)

A minimal Ubuntu autoinstall configuration that:
- Configures basic networking (DHCP)
- Installs cloud-init and Ansible
- Sets up a bootstrap service that runs on first boot
- Fetches role configuration based on MAC address
- Runs ansible-pull to apply the appropriate configuration

### 2. Configuration Server (`config-server/`)

A simple HTTP server that provides:
- **Role Mappings** (`roles/by-mac/*.json`): Maps MAC addresses to server roles
- **User Data** (`users/*.json`): User configurations for each role type
- **Ansible Repository**: Git repository with playbooks and roles

Example structure:
```
config-server/
├── roles/
│   └── by-mac/
│       ├── 00:50:56:12:34:56.json  → github-01 configuration
│       ├── 00:50:56:12:34:57.json  → tools-01 configuration
│       └── 00:50:56:12:34:58.json  → artifacts-01 configuration
└── users/
    ├── github.json     # Users for GitHub servers
    ├── tools.json      # Users for tools servers
    └── artifacts.json  # Users for artifacts servers
```

### 3. Ansible Roles (`ansible/`)

Modular Ansible roles that configure servers:
- **base**: Common configuration for all servers (security, monitoring, firewall)
- **github**: Gitea installation with PostgreSQL backend
- **tools**: Development tools, monitoring stack, container tools
- **artifacts**: Nexus Repository Manager for package/artifact storage

### 4. Example Server Configurations

#### GitHub Server (github-01)
- **Purpose**: On-premise Git repository hosting
- **Software**: Gitea, PostgreSQL, Nginx, Git LFS
- **Users**: gitadmin, developer, cicd
- **Features**: Web UI, SSH access, automated backups

#### Tools Server (tools-01)
- **Purpose**: Development and monitoring tools
- **Software**: Docker, Kubernetes tools, Prometheus, Grafana, development SDKs
- **Users**: devops, developer, monitoring
- **Features**: Container management, metrics collection, log aggregation

#### Artifacts Server (artifacts-01)
- **Purpose**: Package and artifact repository
- **Software**: Nexus Repository Manager, Docker Registry, APT repository
- **Users**: nexusadmin, developer, automation
- **Features**: Maven/npm/Docker repositories, APT mirror, artifact storage

## Setup Instructions

### 1. Set Up Configuration Server

1. Install a basic web server:
```bash
sudo apt-get install nginx git
```

2. Create the configuration directory:
```bash
sudo mkdir -p /var/www/config
sudo cp -r config-server/* /var/www/config/
```

3. Set up Git repository for Ansible:
```bash
cd /var/www/config
git init --bare git/ansible-config.git
# Push the ansible/ directory contents to this repository
```

4. Configure Nginx to serve the configuration:
```nginx
server {
    listen 80;
    server_name config.internal.company.com;
    root /var/www/config;
    
    location / {
        autoindex on;
        try_files $uri $uri/ =404;
    }
    
    location /git/ {
        # Git HTTP backend configuration
        include /etc/nginx/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /usr/lib/git-core/git-http-backend;
        fastcgi_param GIT_HTTP_EXPORT_ALL "";
        fastcgi_param GIT_PROJECT_ROOT /var/www/config/git;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
    }
}
```

### 2. Configure DNS

Add the following to your DNS server:
```
config.internal.company.com    IN  A  192.168.1.10  # Your config server IP
github.internal.company.com     IN  A  192.168.1.20  # Future GitHub server
tools.internal.company.com      IN  A  192.168.1.21  # Future tools server
artifacts.internal.company.com  IN  A  192.168.1.22  # Future artifacts server
```

### 3. Build Bootstrap ISO

```bash
# From the project root
./bin/ubuntu-iso \
    --profile custom \
    --autoinstall /app/share/on-prem-examples/bootstrap-autoinstall.yaml \
    --output ubuntu-24.04.2-bootstrap.iso
```

### 4. Deploy New Servers

1. Create VM with the bootstrap ISO
2. Record the MAC address
3. Create role configuration file on config server:
```bash
# On config server
cat > /var/www/config/roles/by-mac/00:50:56:12:34:56.json << EOF
{
  "hostname": "github-01",
  "role": "github",
  "environment": "production",
  "ansible_tags": ["base", "github", "monitoring"],
  "network": {
    "interface": "ens160",
    "address": "192.168.1.20/24",
    "gateway": "192.168.1.1",
    "nameservers": ["192.168.1.5", "192.168.1.6"]
  }
}
EOF
```

4. Boot the VM - it will automatically:
   - Get DHCP address
   - Run cloud-init
   - Fetch its configuration
   - Apply Ansible roles
   - Configure static IP (if specified)
   - Create users and install software

## Workflow Summary

1. **VM Creation**: New VM boots from bootstrap ISO
2. **Initial Boot**: 
   - DHCP provides temporary IP
   - Cloud-init runs bootstrap script
3. **Configuration Fetch**:
   - Script queries config server with MAC address
   - Retrieves role assignment and network config
4. **Ansible Execution**:
   - ansible-pull clones repository
   - Applies roles based on tags
   - Configures users, packages, and services
5. **Final State**:
   - Server configured for its role
   - Static IP applied (if configured)
   - Services running and monitored

## Security Considerations

1. **Network Isolation**: Keep bootstrap network isolated from production
2. **HTTPS**: Use HTTPS for configuration server in production
3. **Authentication**: Add authentication to configuration endpoints
4. **Secrets Management**: Use Ansible Vault for sensitive data
5. **Firewall Rules**: Default deny with explicit allows
6. **SSH Keys**: Prefer SSH keys over passwords
7. **Audit Logging**: Enable auditd on all systems

## Customization

### Adding New Roles

1. Create Ansible role in `ansible/roles/newrole/`
2. Add tasks and handlers
3. Update `ansible/site.yml` with new role
4. Create user configuration in `config-server/users/newrole.json`
5. Tag servers with the new role in their configuration

### Modifying Bootstrap Process

Edit `bootstrap-autoinstall.yaml` to change:
- Default packages
- Network configuration method
- Storage layout
- Bootstrap script behavior

### Extending Configuration Server

The configuration server can be extended to provide:
- Dynamic inventory for Ansible
- Centralized logging endpoints
- Package mirrors
- Certificate authority
- Monitoring endpoints

## Troubleshooting

### VM Doesn't Configure Itself

1. Check network connectivity:
```bash
ping config.internal.company.com
```

2. Check cloud-init logs:
```bash
sudo journalctl -u cloud-init
sudo cat /var/log/cloud-init.log
```

3. Check bootstrap service:
```bash
sudo systemctl status bootstrap-ansible.service
sudo journalctl -u bootstrap-ansible.service
```

### Wrong Configuration Applied

1. Verify MAC address mapping:
```bash
ip link show
curl http://config.internal.company.com/roles/by-mac/YOUR-MAC.json
```

2. Check Ansible tags:
```bash
ansible-playbook --list-tags site.yml
```

### Network Issues

1. Verify DHCP is working:
```bash
sudo dhclient -v
```

2. Check DNS resolution:
```bash
nslookup config.internal.company.com
```

## Best Practices

1. **Version Control**: Keep all configurations in Git
2. **Testing**: Test role changes in a dev environment first
3. **Documentation**: Document all custom configurations
4. **Monitoring**: Set up monitoring before production use
5. **Backups**: Regular backups of configuration server
6. **Updates**: Regular security updates on all systems

## Example Deployment Scenarios

### Small Team (5-10 servers)
- 1 GitHub server
- 1 Tools server
- 1 Artifacts server
- 2-7 Application servers

### Medium Organization (50-100 servers)
- 2 GitHub servers (HA)
- 2 Tools servers (different teams)
- 2 Artifacts servers (redundancy)
- Multiple application clusters

### Large Enterprise (100+ servers)
- GitHub cluster with replicas
- Regional tools servers
- Distributed artifact caches
- Automated provisioning pipeline

## Integration with Existing Tools

This system can integrate with:
- **Terraform**: For VM provisioning
- **Packer**: For custom base images
- **Vault**: For secrets management
- **Consul**: For service discovery
- **Prometheus**: For monitoring
- **ELK Stack**: For log aggregation
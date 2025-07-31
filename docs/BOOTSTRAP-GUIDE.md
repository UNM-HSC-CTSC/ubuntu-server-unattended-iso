# Bootstrap Guide - Ubuntu Server Unattended ISO Builder

## Table of Contents
- [Overview](#overview)
- [The Bootstrap Problem](#the-bootstrap-problem)
- [Bootstrap Architecture](#bootstrap-architecture)
- [Phase 1: Manual Infrastructure Bootstrap](#phase-1-manual-infrastructure-bootstrap)
- [Phase 2: Automated Operations](#phase-2-automated-operations)
- [Bootstrap ISO Types](#bootstrap-iso-types)
- [Step-by-Step Bootstrap Process](#step-by-step-bootstrap-process)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [See Also](#see-also)

## Overview

This guide explains the bootstrap process for establishing the infrastructure required to support automated server deployments. The bootstrap process solves the "chicken-and-egg" problem where certain infrastructure servers must exist before the automated deployment system can function.

### Key Concepts
- **Bootstrap Servers**: Config and Repository servers that must be deployed manually first
- **Bootstrap ISOs**: Self-contained ISOs that don't depend on external infrastructure
- **Standard ISOs**: Minimal ISOs that require config/repository servers to function
- **Two-Phase Deployment**: Manual bootstrap followed by automated operations

## The Bootstrap Problem

### The Challenge

In our automated deployment system:
1. New servers need a **Configuration Server** to get their Ansible playbooks
2. New servers need a **Repository Server** to download packages and ISOs
3. But these infrastructure servers themselves need to be deployed first!

This creates a circular dependency:
```
New Server → needs → Config Server → needs → ISO → needs → Repository Server → needs → New Server
```

### The Solution

We solve this with a two-phase approach:
1. **Phase 1**: Manually deploy infrastructure servers using self-contained bootstrap ISOs
2. **Phase 2**: Use the infrastructure to automatically deploy all other servers

## Bootstrap Architecture

### Infrastructure Dependencies

```
┌─────────────────────────┐
│   Phase 1: Manual       │
│   Bootstrap             │
├─────────────────────────┤
│ 1. Config Server        │ ← Self-contained ISO
│ 2. Repository Server    │ ← Can use Config Server
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   Phase 2: Automated    │
│   Operations            │
├─────────────────────────┤
│ 3. GitHub Server        │ ← Uses Config + Repo
│ 4. Tools Server         │ ← Uses Config + Repo
│ 5. Any Other Server     │ ← Uses Config + Repo
└─────────────────────────┘
```

### Bootstrap Server Roles

1. **Configuration Server** (`hsc-ctsc-config.health.unm.edu`)
   - Hosts Ansible playbooks
   - Provides role configurations
   - Serves bootstrap scripts
   - Must be deployed first

2. **Repository Server** (`hsc-ctsc-repository.health.unm.edu`)
   - Stores built ISOs
   - Hosts APT package mirror
   - Docker registry
   - Can use Config Server for its setup

## Phase 1: Manual Infrastructure Bootstrap

### Prerequisites

Before starting the bootstrap process, ensure:

1. **Network Infrastructure**
   - F5 BIG-IP configured for DHCP/DNS
   - DNS entries created for infrastructure servers
   - Network connectivity verified

2. **Build Environment**
   - Ubuntu ISO builder installed and tested
   - Access to official Ubuntu ISOs
   - Sufficient disk space for ISO creation

3. **Target Infrastructure**
   - Windows Server 2019 with Hyper-V ready
   - Network share or local storage for ISOs
   - Administrator access to create VMs

### Step 1: Build Config Server Bootstrap ISO

```bash
# Clone the repository (if not already done)
git clone https://github.com/hsc/ubuntu-iso-builder.git
cd ubuntu-iso-builder

# Create config server bootstrap profile
mkdir -p profiles/config-bootstrap

# Create the autoinstall.yaml with self-contained configuration
cat > profiles/config-bootstrap/autoinstall.yaml << 'EOF'
#cloud-config
version: 1

identity:
  hostname: hsc-ctsc-config
  username: configadmin
  password: "$6$rounds=4096$..."  # Generated password hash

network:
  version: 2
  ethernets:
    ens160:
      dhcp4: true

storage:
  config:
    - type: disk
      id: disk0
      match:
        size: largest
    - type: partition
      id: partition-0
      device: disk0
      size: -1
    - type: format
      id: format-0
      volume: partition-0
      fstype: ext4
    - type: mount
      id: mount-0
      device: format-0
      path: /

packages:
  - nginx
  - git
  - ansible
  - python3-pip
  - curl
  - openssh-server

user-data:
  # This runs after first boot
  runcmd:
    # Configure nginx to serve configurations
    - |
      cat > /etc/nginx/sites-available/config << 'NGINX'
      server {
        listen 80;
        server_name hsc-ctsc-config.health.unm.edu;
        root /var/www/config;
        
        location / {
          autoindex on;
          try_files $uri $uri/ =404;
        }
        
        location /git/ {
          # Git HTTP backend
          include /etc/nginx/fastcgi_params;
          fastcgi_param SCRIPT_FILENAME /usr/lib/git-core/git-http-backend;
          fastcgi_param GIT_HTTP_EXPORT_ALL "";
          fastcgi_param GIT_PROJECT_ROOT /var/www/config/git;
          fastcgi_pass unix:/var/run/fcgiwrap.socket;
        }
      }
      NGINX
    
    # Enable the site
    - ln -s /etc/nginx/sites-available/config /etc/nginx/sites-enabled/
    - systemctl restart nginx
    
    # Create directory structure
    - mkdir -p /var/www/config/{ansible,scripts,roles}
    
    # Initialize git repository for Ansible
    - cd /var/www/config/git && git init --bare ansible-config.git
    
    # Create a marker file to indicate successful bootstrap
    - touch /var/www/config/.bootstrap-complete

late-commands:
  - curtin in-target -- systemctl enable ssh
  - curtin in-target -- systemctl enable nginx
EOF

# Build the Config Server Bootstrap ISO
./bin/ubuntu-iso \
  --profile config-bootstrap \
  --output output/ubuntu-24.04.2-config-bootstrap.iso
```

### Step 2: Deploy Config Server

1. **Copy ISO to Hyper-V Host**
```powershell
# On Hyper-V host
Copy-Item "\\workstation\share\ubuntu-24.04.2-config-bootstrap.iso" "C:\ISOs\"
```

2. **Create VM in Hyper-V**
```powershell
# Create the VM
New-VM -Name "hsc-ctsc-config" `
  -MemoryStartupBytes 4GB `
  -Generation 2 `
  -NewVHDPath "C:\VMs\hsc-ctsc-config\disk.vhdx" `
  -NewVHDSizeBytes 50GB `
  -SwitchName "External"

# Attach the ISO
Add-VMDvdDrive -VMName "hsc-ctsc-config" `
  -Path "C:\ISOs\ubuntu-24.04.2-config-bootstrap.iso"

# Configure boot order
Set-VMFirmware -VMName "hsc-ctsc-config" `
  -FirstBootDevice (Get-VMDvdDrive -VMName "hsc-ctsc-config")

# Start the VM
Start-VM -Name "hsc-ctsc-config"
```

3. **Wait for Installation**
   - Ubuntu autoinstaller will run automatically
   - System will reboot when complete
   - Cloud-init will configure on first boot

4. **Verify Config Server**
```bash
# From your workstation
curl http://hsc-ctsc-config.health.unm.edu/
# Should see nginx directory listing

# Check bootstrap marker
curl http://hsc-ctsc-config.health.unm.edu/.bootstrap-complete
# Should return 200 OK
```

### Step 3: Populate Config Server

Before deploying other servers, populate the config server with Ansible playbooks:

```bash
# From your workstation with the ansible roles
cd ubuntu-iso-builder/ansible

# Push to config server
git init
git add .
git commit -m "Initial ansible configuration"
git remote add origin http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
git push -u origin main
```

### Step 4: Build Repository Server Bootstrap ISO

```bash
# Create repository bootstrap profile
mkdir -p profiles/repository-bootstrap

cat > profiles/repository-bootstrap/autoinstall.yaml << 'EOF'
#cloud-config
version: 1

identity:
  hostname: hsc-ctsc-repository
  username: repoadmin
  password: "$6$rounds=4096$..."  # Generated password hash

# ... (similar to config but includes)

user-data:
  runcmd:
    # This server CAN use the config server
    - |
      # Wait for network
      until ping -c1 hsc-ctsc-config.health.unm.edu; do sleep 5; done
      
      # Get Ansible configuration
      cd /tmp
      git clone http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
      
      # Run ansible-pull for repository role
      cd ansible-config
      ansible-playbook -i localhost, -c local -t repository site.yml
EOF

# Build Repository Server ISO
./bin/ubuntu-iso \
  --profile repository-bootstrap \
  --output output/ubuntu-24.04.2-repository-bootstrap.iso
```

### Step 5: Deploy Repository Server

Deploy similar to config server, using the repository-bootstrap ISO.

## Phase 2: Automated Operations

Once both infrastructure servers are operational:

### GitHub Actions Workflow

```yaml
# .github/workflows/build-and-deploy.yml
name: Build and Deploy ISOs

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      role:
        description: 'Server role to build'
        required: true
        type: choice
        options:
          - github
          - tools
          - all

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        role: [github, tools]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build ISO
        run: |
          ./bin/ubuntu-iso \
            --profile ${{ matrix.role }}-server \
            --output ubuntu-${{ matrix.role }}.iso
      
      - name: Upload to Repository
        run: |
          curl -X POST https://hsc-ctsc-repository.health.unm.edu/api/upload \
            -F "file=@ubuntu-${{ matrix.role }}.iso" \
            -F "version=${{ github.sha }}" \
            -F "role=${{ matrix.role }}"
```

### Standard Server Deployment

For all non-bootstrap servers:

```powershell
# Download ISO from repository
Invoke-WebRequest `
  -Uri "https://hsc-ctsc-repository.health.unm.edu/isos/ubuntu-github-latest.iso" `
  -OutFile "C:\ISOs\ubuntu-github.iso"

# Create and start VM
New-VM -Name "hsc-ctsc-github-01" -MemoryStartupBytes 8GB -Generation 2
# ... (attach ISO and start)
```

The server will:
1. Boot from ISO
2. Get IP from F5 DHCP
3. Read embedded role from cloud-init
4. Contact config server
5. Pull Ansible configuration
6. Configure itself completely

## Bootstrap ISO Types

### Config Bootstrap ISO

**Purpose**: Deploy the configuration server without any dependencies

**Contains**:
- Full nginx configuration
- Git server setup
- All required packages
- Self-contained cloud-init

**Special Considerations**:
- Must not depend on any external services
- Contains all configuration inline
- Larger than standard ISOs

### Repository Bootstrap ISO

**Purpose**: Deploy the repository server with minimal dependencies

**Contains**:
- Basic system configuration
- Instructions to contact config server
- Repository software (Nexus/similar)

**Dependencies**:
- Config server must be operational
- Network connectivity to config server

### Standard ISOs

**Purpose**: Deploy all other servers efficiently

**Contains**:
- Minimal base system
- Cloud-init with role metadata
- Bootstrap script to contact config server

**Dependencies**:
- Both config and repository servers operational
- Network connectivity to infrastructure

## Step-by-Step Bootstrap Process

### Complete Bootstrap Sequence

1. **Preparation**
   ```bash
   # Ensure DNS is configured
   nslookup hsc-ctsc-config.health.unm.edu
   nslookup hsc-ctsc-repository.health.unm.edu
   ```

2. **Build Bootstrap ISOs**
   ```bash
   # Config server
   ./bin/ubuntu-iso --profile config-bootstrap --output ubuntu-config-bootstrap.iso
   
   # Repository server  
   ./bin/ubuntu-iso --profile repository-bootstrap --output ubuntu-repository-bootstrap.iso
   ```

3. **Deploy Config Server**
   - Create VM with config-bootstrap ISO
   - Wait for installation and cloud-init
   - Verify nginx is serving
   - Push Ansible playbooks

4. **Deploy Repository Server**
   - Create VM with repository-bootstrap ISO
   - Wait for installation
   - Verify it pulled config from config server
   - Verify repository is accessible

5. **Configure CI/CD**
   - Set up GitHub Actions secrets
   - Configure repository credentials
   - Test ISO build and upload

6. **Deploy First Standard Server**
   - Build standard ISO (e.g., tools server)
   - Deploy and verify automated configuration
   - Confirm full automation works

## Troubleshooting

### Common Bootstrap Issues

#### Config Server Not Accessible
```bash
# Check nginx status
ssh configadmin@hsc-ctsc-config.health.unm.edu
sudo systemctl status nginx
sudo nginx -t

# Check firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

#### Repository Server Can't Reach Config
```bash
# Test connectivity
ping hsc-ctsc-config.health.unm.edu
curl http://hsc-ctsc-config.health.unm.edu/

# Check DNS
nslookup hsc-ctsc-config.health.unm.edu
cat /etc/resolv.conf
```

#### Ansible-Pull Fails
```bash
# Check git repository
git clone http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
cd ansible-config
ansible-playbook --syntax-check site.yml

# Run with verbose output
ansible-pull -vvv -U http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
```

#### ISO Build Fails
```bash
# Check available space
df -h

# Verify downloads cache
ls -la cache/

# Run with verbose mode
VERBOSE=1 ./bin/ubuntu-iso --profile config-bootstrap
```

### Recovery Procedures

#### Rebuild Config Server
1. Back up existing configurations:
   ```bash
   # From config server
   tar czf config-backup.tar.gz /var/www/config/
   ```

2. Rebuild with bootstrap ISO
3. Restore configurations:
   ```bash
   tar xzf config-backup.tar.gz -C /
   ```

#### Repository Server Recovery
1. Ensure config server is operational
2. Rebuild with repository-bootstrap ISO
3. Re-sync ISOs from GitHub Actions

## Best Practices

### Bootstrap Guidelines

1. **Always Bootstrap in Order**
   - Config server first
   - Repository server second
   - Other infrastructure third

2. **Verify Each Step**
   - Don't proceed until previous step works
   - Test connectivity and services
   - Check logs for errors

3. **Document Customizations**
   - Record any manual changes
   - Update bootstrap ISOs accordingly
   - Keep documentation current

4. **Backup Critical Configurations**
   - Config server Git repositories
   - Repository server metadata
   - Custom scripts and configurations

### Security During Bootstrap

1. **Change Default Passwords**
   - Update immediately after bootstrap
   - Use strong, unique passwords
   - Consider SSH key-only access

2. **Enable Firewalls**
   - Configure ufw on each server
   - Only allow required ports
   - Log connection attempts

3. **Update Systems**
   - Run updates after bootstrap
   - Enable automatic security updates
   - Monitor for vulnerabilities

### Maintenance

1. **Regular Testing**
   - Periodically test bootstrap process
   - Verify ISOs still build correctly
   - Test disaster recovery

2. **Keep Bootstrap ISOs Updated**
   - Rebuild with latest Ubuntu updates
   - Update embedded configurations
   - Test thoroughly before use

3. **Monitor Infrastructure Servers**
   - Set up monitoring early
   - Alert on service failures
   - Track disk usage

## See Also

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Deploying standard servers
- [ROLE-DEFINITIONS.md](ROLE-DEFINITIONS.md) - Available server roles
- [Ansible Documentation](../ansible/README.md) - Ansible role details
- [README.md](../README.md) - Project overview
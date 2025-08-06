# Server Role Definitions

## Table of Contents
- [Overview](#overview)
- [Infrastructure Roles](#infrastructure-roles)
  - [Config Server](#config-server)
  - [Repository Server](#repository-server)
- [Service Roles](#service-roles)
  - [GitHub Server](#github-server)
  - [Tools Server](#tools-server)
  - [Artifacts Server](#artifacts-server)
- [Creating Custom Roles](#creating-custom-roles)
- [Role Configuration Details](#role-configuration-details)
- [Best Practices](#best-practices)
- [See Also](#see-also)

## Overview

This document defines all available server roles in the Ubuntu Server Unattended ISO Builder system. Each role represents a specific server configuration with predetermined packages, services, and settings.

### Role Architecture

```
┌─────────────────────────────────────────┐
│             Server Roles                │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────┐  ┌─────────────┐      │
│  │Infrastructure│  │   Service    │      │
│  │    Roles    │  │    Roles     │      │
│  ├─────────────┤  ├─────────────┤      │
│  │ • Config    │  │ • GitHub     │      │
│  │ • Repository│  │ • Tools      │      │
│  └─────────────┘  │ • Artifacts  │      │
│                   │ • Monitoring │      │
│                   │ • Custom...  │      │
│                   └─────────────┘      │
└─────────────────────────────────────────┘
```

### Role Components

Each role consists of:
- **Profile**: ISO configuration (`/profiles/role-name/`)
- **Ansible Role**: Configuration playbook (`/ansible/roles/role-name/`)
- **Cloud-init**: First-boot setup
- **Packages**: Software to install
- **Services**: Daemons to configure
- **Users**: Accounts to create

## Infrastructure Roles

These roles provide core infrastructure services required by other servers.

### Config Server

**Purpose**: Central configuration management and source of truth

**Hostname Pattern**: `hsc-ctsc-config`, `config.company.com`

**Key Features**:
- Hosts Ansible playbooks via Git
- Serves configuration files via HTTP/HTTPS
- Provides role mappings
- No external dependencies (bootstrap role)

**Services**:
```yaml
- nginx           # Web server for configurations
- git-daemon      # Git repository hosting
- fcgiwrap        # Git HTTP backend
```

**Packages**:
```yaml
- nginx
- git
- ansible
- python3-pip
- fcgiwrap
- ssl-cert
```

**Directory Structure**:
```
/var/www/config/
├── ansible/          # Ansible playbooks
├── roles/            # Role configurations
├── scripts/          # Bootstrap scripts
└── git/              # Git repositories
    └── ansible-config.git
```

**Network Requirements**:
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 9418 (Git)

**Storage Requirements**:
- Minimum: 20GB
- Recommended: 50GB

**Special Considerations**:
- Must be deployed first
- Uses bootstrap ISO (self-contained)
- Should be highly available in production

### Repository Server

**Purpose**: Store and distribute ISOs, packages, and artifacts

**Hostname Pattern**: `hsc-ctsc-repository`, `repository.company.com`

**Key Features**:
- ISO storage with API
- APT package mirror
- Docker registry
- Artifact repository

**Services**:
```yaml
- nexus           # Nexus Repository Manager
- nginx           # Reverse proxy
- postgresql      # Database for Nexus
```

**Packages**:
```yaml
- openjdk-11-jdk
- nginx
- postgresql
- docker.io
- apache2-utils
```

**Storage Layout**:
```
/opt/repository/
├── isos/             # ISO images
├── apt/              # APT mirror
├── docker/           # Docker registry
└── artifacts/        # Generic artifacts
```

**API Endpoints**:
```
POST   /api/upload     # Upload new ISO
GET    /api/isos       # List ISOs
DELETE /api/isos/{id}  # Remove ISO
GET    /isos/{name}    # Download ISO
```

**Network Requirements**:
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 5000 (Docker Registry)
- Port 8080 (APT Repository)

**Storage Requirements**:
- Minimum: 100GB
- Recommended: 500GB+

**Special Considerations**:
- Can use config server for setup
- Requires significant storage
- Should implement cleanup policies

## Service Roles

These roles provide specific services for users and applications.

### GitHub Server

**Purpose**: GitHub Actions self-hosted runners for CI/CD

**Hostname Pattern**: `hsc-ctsc-github-##`, `github-runners.company.com`

**Key Features**:
- Multiple concurrent runners (default: 4)
- Docker support for containerized builds
- Ephemeral runners for security
- Automated cleanup and maintenance
- Enterprise-ready monitoring

**Services**:
```yaml
- github-runner@1-4  # Runner services
- docker             # Container runtime
- prometheus-node-exporter  # Metrics
```

**Packages**:
```yaml
# Core runner requirements
- curl, wget, git
- build-essential
- docker.io, docker-compose

# Development tools
- python3-pip, python3-venv
- nodejs (optional)
- golang (optional)
```

**Configuration**:
```yaml
# Runner Configuration
runner_count: 4
runner_labels: "self-hosted,linux,x64,ubuntu-24.04,docker"
runner_ephemeral: true
runner_group: "default"

# Features
docker_enabled: true
docker_privileged: false
cache_enabled: true

# Resource limits per runner
runner_cpu_limit: "2"
runner_memory_limit: "4G"
runner_disk_quota: "50G"
```

**Runner Users**:
- `runner` - Primary runner
- `runner2-4` - Additional runners
- `sysadmin` - System administrator

**Network Requirements**:
- Port 22 (SSH management)
- Port 443 (HTTPS to GitHub Enterprise) - outbound only
- Port 80 (HTTP to GitHub Enterprise) - outbound only
- Port 9100 (Prometheus metrics)

**Storage Requirements**:
- Minimum: 100GB
- Recommended: 500GB+ (for Docker images and build artifacts)
- Work directory: `/home/runner*/work`

**Management**:
- Registration: `sudo register-runner`
- Status: `sudo runner-status`
- Health check: `sudo runner-health-check`
- Updates: `sudo update-runners`

### Tools Server

**Purpose**: Development and monitoring tools

**Hostname Pattern**: `hsc-ctsc-tools-##`, `tools.company.com`

**Key Features**:
- Development environments
- Container management
- Monitoring stack
- Build tools

**Services**:
```yaml
- docker          # Container runtime
- prometheus      # Metrics collection
- grafana         # Visualization
- elasticsearch   # Log storage
- kibana          # Log visualization
```

**Packages**:
```yaml
# Development Tools
- build-essential
- gcc, g++, make, cmake
- git, vim, emacs
- python3-pip, nodejs, npm
- golang-go, openjdk-17-jdk

# Container Tools
- docker.io
- docker-compose
- podman
- kubectl

# Monitoring Tools
- prometheus
- grafana
- elasticsearch
- logstash
- kibana
```

**Tool Categories**:

**Development**:
- Multiple language SDKs
- Version control tools
- IDE support packages
- Database clients

**Infrastructure**:
- Terraform
- Ansible
- Packer
- Cloud CLIs

**Monitoring**:
- Prometheus (port 9090)
- Grafana (port 3000)
- Kibana (port 5601)

**Default Users**:
- `devops` - DevOps engineer
- `developer` - Developer access
- `monitoring` - Read-only monitoring

**Network Requirements**:
- Port 3000 (Grafana)
- Port 9090 (Prometheus)
- Port 5601 (Kibana)
- Port 9200 (Elasticsearch)

**Storage Requirements**:
- Minimum: 100GB
- Recommended: 500GB+ (for logs/metrics)

### Artifacts Server

**Purpose**: Package and artifact repository

**Hostname Pattern**: `hsc-ctsc-artifacts-##`, `artifacts.company.com`

**Key Features**:
- Maven/Gradle repository
- NPM registry
- PyPI mirror
- Generic file storage

**Services**:
```yaml
- nexus           # Nexus Repository Manager
- nginx           # Reverse proxy
- docker          # For Docker registry
```

**Repository Types**:
```yaml
maven:
  - maven-central (proxy)
  - maven-releases
  - maven-snapshots

npm:
  - npm-registry (proxy)
  - npm-private

python:
  - pypi (proxy)
  - pypi-private

docker:
  - docker-hub (proxy)
  - docker-private

raw:
  - files
  - isos
  - binaries
```

**Configuration Example**:
```yaml
# Maven repository
repositories:
  maven-releases:
    type: hosted
    format: maven2
    policy: release
    
  maven-central:
    type: proxy
    format: maven2
    remote_url: https://repo1.maven.org/maven2/
```

**Default Users**:
- `nexusadmin` - Administrator
- `developer` - Upload/download
- `automation` - CI/CD access

**Network Requirements**:
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 5000 (Docker)
- Port 8081 (Nexus)

**Storage Requirements**:
- Minimum: 200GB
- Recommended: 1TB+

**Cleanup Policies**:
- Remove snapshots > 30 days
- Remove unused Docker layers
- Compress old artifacts

## Creating Custom Roles

### Step 1: Create Profile Directory

```bash
mkdir -p profiles/myrole
```

### Step 2: Create autoinstall.yaml

```yaml
#cloud-config
version: 1

identity:
  hostname: myrole-server
  username: myadmin
  password: $6$rounds=4096$...

user-data:
  role: myrole
  config_server: hsc-ctsc-config.health.unm.edu
  runcmd:
    - |
      ansible-pull \
        -U http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git \
        -C main \
        -t myrole \
        site.yml
```

### Step 3: Create Ansible Role

```bash
mkdir -p ansible/roles/myrole/{tasks,handlers,templates,files}
```

Create `ansible/roles/myrole/tasks/main.yml`:
```yaml
---
- name: Install required packages
  apt:
    name:
      - package1
      - package2
    state: present

- name: Configure service
  template:
    src: config.j2
    dest: /etc/myapp/config.yml
  notify: restart myapp

- name: Start and enable service
  systemd:
    name: myapp
    state: started
    enabled: yes
```

### Step 4: Update site.yml

```yaml
- name: Configure myrole server
  hosts: localhost
  connection: local
  become: yes
  tags: myrole
  roles:
    - base
    - myrole
```

### Step 5: Document the Role

Add to this file with:
- Purpose and features
- Required packages
- Network ports
- Storage needs
- User accounts

## Role Configuration Details

### Common Configuration

All roles include these base configurations:

**Security**:
- UFW firewall enabled
- Fail2ban configured
- Automatic security updates
- SSH key authentication

**Monitoring**:
- Node exporter (port 9100)
- Log shipping configured
- Health check endpoints

**Management**:
- Standard admin user
- Sudo configuration
- Time synchronization
- System logging

### Role Interactions

```
┌─────────────┐
│   Config    │ ← All roles pull configuration
└──────┬──────┘
       │
┌──────┴──────┐     ┌─────────────┐
│   GitHub    │────▶│    Tools    │
│  (source)   │     │   (build)   │
└─────────────┘     └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │  Artifacts  │
                    │  (storage)  │
                    └─────────────┘
```

### Environment Variables

Roles can be customized via environment:

```yaml
# In autoinstall.yaml
user-data:
  role: github
  environment: production
  config:
    github_url: github.company.com
    github_admin_email: admin@company.com
```

## Best Practices

### Role Design

1. **Single Responsibility**
   - Each role has one primary purpose
   - Avoid role sprawl
   - Compose complex systems from multiple roles

2. **Idempotency**
   - Roles can be run multiple times safely
   - Check before making changes
   - Use Ansible modules properly

3. **Parameterization**
   - Make roles configurable
   - Use variables for environment-specific values
   - Document all parameters

### Security

1. **Least Privilege**
   - Only install required packages
   - Minimal user permissions
   - Restricted network access

2. **Secrets Management**
   - Never hardcode passwords
   - Use Vault for sensitive data
   - Rotate credentials regularly

3. **Network Security**
   - Enable firewall rules
   - Use HTTPS where possible
   - Implement network segmentation

### Maintenance

1. **Updates**
   - Keep base packages updated
   - Monitor security advisories
   - Plan maintenance windows

2. **Monitoring**
   - All roles export metrics
   - Configure alerting
   - Log aggregation

3. **Backup**
   - Document what needs backing up
   - Automate backup processes
   - Test restore procedures

## See Also

- [Architecture Overview](ARCHITECTURE.md) - System design
- [Bootstrap Guide](BOOTSTRAP-GUIDE.md) - Infrastructure setup
- [Deployment Guide](DEPLOYMENT-GUIDE.md) - Deployment procedures
- [Ansible Documentation](../ansible/README.md) - Role implementation
- [README.md](../README.md) - Project overview
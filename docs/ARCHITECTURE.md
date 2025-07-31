# Ubuntu Server Unattended ISO Builder - Technical Architecture

## Table of Contents
- [Overview](#overview)
- [System Components](#system-components)
- [Infrastructure Requirements](#infrastructure-requirements)
- [Data Flow](#data-flow)
- [Bootstrap Architecture](#bootstrap-architecture)
- [Security Architecture](#security-architecture)
- [Network Topology](#network-topology)
- [Technology Stack](#technology-stack)
- [Design Decisions](#design-decisions)
- [See Also](#see-also)

## Overview

The Ubuntu Server Unattended ISO Builder is a comprehensive system for creating and deploying self-configuring Ubuntu Server installations. It combines ISO building capabilities with cloud-init and Ansible to create servers that automatically configure themselves based on assigned roles.

### Key Features
- **Automated ISO Building**: Creates unattended Ubuntu Server ISOs with embedded configurations
- **Role-Based Configuration**: Servers configure themselves based on assigned roles (config, repository, github, tools, etc.)
- **Two-Phase Bootstrap**: Solves the chicken-and-egg problem of infrastructure dependencies
- **CI/CD Integration**: GitHub Actions builds and distributes ISOs automatically
- **Zero-Touch Deployment**: Once infrastructure exists, new servers self-configure without manual intervention

### Architecture Principles
1. **Native Tools Only**: Uses only tools pre-installed on Ubuntu (no external dependencies)
2. **Pull-Based Configuration**: Servers pull their configuration for security
3. **Metadata-Driven**: Uses cloud-init metadata, not hardcoded mappings
4. **GitOps**: All configurations stored in version control
5. **Immutable Infrastructure**: ISOs are built with specific roles embedded

## System Components

### 1. ISO Builder (`/bin/ubuntu-iso`)
- **Purpose**: Creates customized Ubuntu Server ISOs
- **Technology**: Bash scripts using native Linux tools (genisoimage, xorriso)
- **Features**:
  - Downloads official Ubuntu ISOs
  - Injects autoinstall.yaml configurations
  - Embeds cloud-init metadata
  - Validates configurations
  - Supports multiple Ubuntu versions

### 2. Profiles System (`/profiles/`)
- **Purpose**: Define different server configurations
- **Structure**:
  ```
  profiles/
  ├── bootstrap/           # Minimal bootstrap configuration
  ├── config-bootstrap/    # Config server bootstrap (self-contained)
  ├── repository-bootstrap/# Repository server bootstrap
  ├── github-server/       # GitHub/Gitea server role
  ├── tools-server/        # Development tools role
  └── artifacts-server/    # Package repository role
  ```
- **Components**: Each profile contains:
  - `autoinstall.yaml`: Ubuntu autoinstaller configuration
  - `README.md`: Profile documentation
  - Cloud-init user-data and meta-data

### 3. Ansible Roles (`/ansible/`)
- **Purpose**: Define server configurations by role
- **Roles**:
  - `base`: Common configuration for all servers
  - `config`: Configuration server setup
  - `repository`: Artifact repository (Nexus, APT mirror)
  - `github`: Git server (Gitea) with PostgreSQL
  - `tools`: Development and monitoring tools
- **Execution**: Via ansible-pull (no central Ansible server required)

### 4. GitHub Actions CI/CD (`.github/workflows/`)
- **Purpose**: Automated building and testing
- **Workflows**:
  - `ci.yml`: Tests, builds ISOs, uploads to repository
  - Security scanning
  - Automated releases
- **Artifact Distribution**: Uploads ISOs to repository server

### 5. Configuration Server (`hsc-ctsc-config.health.unm.edu`)
- **Purpose**: Central source of truth for configurations
- **Serves**:
  - Ansible playbooks via Git
  - Role configurations
  - User definitions
  - Bootstrap scripts
- **Technology**: Nginx, Git server

### 6. Repository Server
- **Purpose**: Stores built ISOs and packages
- **Features**:
  - ISO storage with versioning
  - APT package mirror
  - Docker registry
  - API for GitHub Actions uploads
- **Technology**: Nexus Repository Manager or similar

## Infrastructure Requirements

### Network Infrastructure
- **F5 BIG-IP**: Provides DHCP and DNS services
  - Assigns IP addresses to new VMs
  - Resolves internal DNS names
  - Load balancing for services

### DNS Requirements
- `hsc-ctsc-config.health.unm.edu` → Configuration server
- `hsc-ctsc-repository.health.unm.edu` → Repository server
- `hsc-ctsc-github.health.unm.edu` → GitHub server
- Additional DNS entries for each service

### Compute Infrastructure
- **Windows Server 2019 with Hyper-V**: VM host platform
- **Requirements**:
  - PowerShell 5.1 or later
  - Sufficient storage for ISOs
  - Network access to repository server

### Storage Requirements
- **ISO Storage**: ~3GB per ISO version
- **Repository Storage**: Depends on retention policy
- **VM Storage**: Varies by role (10-100GB per VM)

## Data Flow

### Build and Distribution Flow
```
1. Developer pushes code → GitHub
2. GitHub Actions triggered
3. ISO Builder creates role-specific ISOs
4. ISOs uploaded to Repository Server
5. Repository indexes and stores ISOs
6. Hyper-V admin downloads ISOs
7. Creates VMs with ISOs attached
```

### VM Bootstrap Flow
```
1. VM boots from ISO
2. Ubuntu Autoinstaller runs
3. Cloud-init executes on first boot
4. Reads embedded role metadata
5. Contacts Configuration Server
6. Downloads Ansible playbooks via Git
7. Runs ansible-pull with role tags
8. Server fully configured
```

### Configuration Update Flow
```
1. Admin updates Ansible roles
2. Pushes to Git repository
3. Configuration server updates
4. Existing servers pull updates (optional)
5. New servers get latest on bootstrap
```

## Bootstrap Architecture

See [BOOTSTRAP-GUIDE.md](BOOTSTRAP-GUIDE.md) for detailed bootstrap procedures.

### The Bootstrap Problem
- Config server needs to exist before other servers can use it
- Repository server needs to exist to store ISOs
- These servers need special "bootstrap" ISOs that don't depend on infrastructure

### Two-Phase Approach

#### Phase 1: Infrastructure Bootstrap
1. **Build bootstrap ISOs locally** (config and repository servers)
2. **Deploy config server** using self-contained bootstrap ISO
3. **Deploy repository server** using its bootstrap ISO
4. **Infrastructure ready** for automated operations

#### Phase 2: Automated Operations
1. **GitHub Actions** builds role-specific ISOs
2. **Uploads to repository** server automatically
3. **New VMs** deployed with standard ISOs
4. **Self-configuration** via config server

### Bootstrap vs Standard ISOs
- **Bootstrap ISOs**: Self-contained, no external dependencies
- **Standard ISOs**: Minimal, depend on config/repository servers

## Security Architecture

### Security Principles
1. **Pull-based configuration**: No inbound SSH to production servers
2. **Secrets management**: Integration with HashiCorp Vault (future)
3. **Network segmentation**: Management network separate from production
4. **Audit logging**: All configuration changes logged
5. **GitOps**: Version control for all configurations

### Security Controls
- **ISO Integrity**: Checksums verified during download
- **HTTPS Only**: All communication encrypted
- **Authentication**: Service accounts for automation
- **Authorization**: Role-based access control
- **Firewall Rules**: Default deny with explicit allows

### Compliance Considerations
- **Change Management**: Git history provides audit trail
- **Configuration Drift**: Ansible ensures desired state
- **Patch Management**: Automated security updates
- **Access Control**: SSH key-based authentication

## Network Topology

```
Internet
    │
    ├─── GitHub (Actions, Repository)
    │
┌───┴────────────────────────────────────┐
│          F5 BIG-IP                     │
│  (DHCP, DNS, Load Balancing)           │
└────┬───────────────────────────────────┘
     │
┌────┴───────────────────────────────────┐
│       Management Network               │
│  ┌─────────────┐  ┌─────────────┐     │
│  │Config Server│  │ Repository  │     │
│  │  (Ansible)  │  │   Server    │     │
│  └─────────────┘  └─────────────┘     │
│                                        │
│  ┌─────────────┐  ┌─────────────┐     │
│  │   Hyper-V   │  │   Admin     │     │
│  │    Host     │  │ Workstation │     │
│  └─────────────┘  └─────────────┘     │
└────────────────────────────────────────┘
     │
┌────┴───────────────────────────────────┐
│       Production Network               │
│  ┌─────────────┐  ┌─────────────┐     │
│  │   GitHub    │  │   Tools     │     │
│  │   Server    │  │   Server    │     │
│  └─────────────┘  └─────────────┘     │
│                                        │
│  ┌─────────────┐  ┌─────────────┐     │
│  │Application  │  │  Database   │     │
│  │  Servers    │  │  Servers    │     │
│  └─────────────┘  └─────────────┘     │
└────────────────────────────────────────┘
```

### Network Segmentation
- **Management Network**: Config, repository, Hyper-V management
- **Production Network**: Application servers
- **DMZ** (if applicable): External-facing services

## Technology Stack

### Core Technologies
- **Ubuntu Server 24.04 LTS**: Base operating system
- **Cloud-init**: First-boot configuration
- **Ansible**: Configuration management
- **Git**: Version control
- **Bash**: Scripting and automation

### ISO Building
- **genisoimage/mkisofs**: ISO creation
- **xorriso**: ISO manipulation
- **Python**: Fallback ISO tools
- **YAML**: Configuration format

### Infrastructure Services
- **Nginx**: Web server for config/repository
- **PostgreSQL**: Database for Gitea
- **Docker**: Container runtime
- **Prometheus/Grafana**: Monitoring (optional)

### CI/CD
- **GitHub Actions**: Build automation
- **GitHub CLI**: Repository management
- **PowerShell**: Windows automation

## Design Decisions

### Why Not Use Existing Tools?

#### No Packer
- **Reason**: Packer creates VM images, not bootable ISOs
- **Our Need**: Bootable ISOs for bare metal or new VMs

#### No Terraform/Pulumi
- **Reason**: Limited Hyper-V support, adds complexity
- **Our Solution**: Simple PowerShell scripts for VM creation

#### No Configuration Management Server
- **Reason**: Additional infrastructure, security concerns
- **Our Solution**: ansible-pull for distributed execution

### Key Design Choices

#### Cloud-init with NoCloud
- **Why**: Works without cloud provider
- **Benefit**: Same tool works on-premise and cloud

#### Pull-based Configuration
- **Why**: Security (no inbound SSH)
- **Benefit**: Scales without central server

#### Role-embedded ISOs
- **Why**: Simpler than runtime role assignment
- **Benefit**: Predictable, reproducible deployments

#### Native Tools Only
- **Why**: Maximum compatibility
- **Benefit**: Works in restricted environments

### Trade-offs

#### Pros
- Simple architecture
- Minimal dependencies
- Secure by design
- Version controlled
- Auditable

#### Cons
- ISO storage requirements
- Bootstrap complexity
- No dynamic role assignment
- Manual Hyper-V operations

## See Also

- [BOOTSTRAP-GUIDE.md](BOOTSTRAP-GUIDE.md) - Detailed bootstrap procedures
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Step-by-step deployment instructions
- [ROLE-DEFINITIONS.md](ROLE-DEFINITIONS.md) - Available server roles
- [README.md](../README.md) - Project overview
- [CLAUDE.md](../CLAUDE.md) - Development context and decisions
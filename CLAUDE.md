# Ubuntu Server Unattended ISO Builder - Technical Architecture

## Overview
This project is a **tool** for creating custom Ubuntu Server installation ISOs with automated installation configurations. Users can either use the provided base configuration or generate their own custom autoinstall.yaml using the interactive wizard.

## 🔄 Project Status: Major Refactoring in Progress

### Current State (as of last session):
The project is undergoing a major refactoring to follow industry standards and simplify its purpose:

**Completed Refactoring:**
- ✅ Created `lib/` directory with shared libraries (common.sh, download.sh, validate.sh)
- ✅ Moved test scripts to `tests/` directory
- ✅ Created `share/` directory with ubuntu-base and examples
- ✅ Fixed generate-autoinstall to handle --help flag
- ✅ Fixed GitHub Actions infinite loop issue
- ✅ Updated .env.example with simplified variables
- ✅ Removed ISO building from CI/CD (storage optimization)

**Still TODO:**
- 🔄 Rename bin commands to `ubuntu-iso` and `ubuntu-iso-generate`
- 🔄 Remove duplicate scripts from scripts/
- 🔄 Update build-iso to use new lib functions
- 🔄 Remove template-secure and credential complexity
- 🔄 Create LICENSE, CONTRIBUTING.md, etc.
- 🔄 Update README to reflect new structure

### Key Decisions Made:
1. **Single ISO approach** - Build one base ISO, users customize via generator
2. **No pre-built artifacts** - GitHub Actions only tests, users build locally
3. **Industry standard structure** - lib/ for libraries, bin/ for commands, share/ for data
4. **Simplified configuration** - Removed credential variables and template-secure complexity

## New Project Structure (Industry Standard)

```
ubuntu-iso-builder/
├── bin/                    # User-facing commands
│   ├── build-iso          # (to be renamed: ubuntu-iso)
│   ├── generate-autoinstall # (to be renamed: ubuntu-iso-generate)
│   └── build-all          # (to be removed - no longer needed)
├── lib/                    # Shared libraries (sourced, not executed)
│   ├── common.sh          # Colors, logging, error handling
│   ├── download.sh        # ISO download with validation
│   ├── validate.sh        # YAML and autoinstall validation
│   └── iso-tools.sh       # ISO manipulation functions
├── share/                  # Data files
│   ├── ubuntu-base/       # Default minimal configuration
│   └── examples/          # Reference configurations
│       ├── web-server/
│       ├── database-server/
│       └── container-host/
├── tests/                  # Test scripts
│   ├── test-dependencies.sh
│   ├── test-credential-simple.sh
│   └── ... (other tests)
├── scripts/                # (to be cleaned up - remove duplicates)
├── profiles/               # (to be removed - replaced by share/)
├── .env.example           # Simplified configuration template
├── Makefile               # Main entry point
└── README.md              # (needs update)
```

## Implementation Summary

### Core Components

#### 1. Main Scripts
- **bin/build-iso**: Primary ISO builder with validation integration
  - Profile validation
  - Autoinstall validation (with --skip-validation option)
  - ISO download with caching
  - ISO manipulation via abstraction layer
  - Autoinstall injection
  - ISO repackaging

- **bin/generate-autoinstall**: Interactive profile generator (482 lines)
  - Guided wizard interface
  - Network configuration (DHCP/static)
  - User and SSH key setup
  - Storage layout options
  - Package selection
  - Security configuration

- **bin/build-all**: Batch profile builder
  - Iterates through all profiles
  - Provides summary statistics
  - Handles failures gracefully

- **test.sh**: Comprehensive test suite
  - 13 test categories
  - Environment validation
  - Profile structure checks
  - Tool availability verification
  - NO_COLOR support for CI/CD

### Helper Scripts

#### Validation Scripts
- **validate-autoinstall.sh**: Comprehensive autoinstall validation
  - Subiquity validator integration (when available)
  - Local Python-based validation fallback
  - Cloud-config header checking
  - Required field validation
  - Exit code fix for proper operation

- **validate-yaml-syntax.sh**: YAML syntax validation
  - Python-based implementation
  - No external dependencies
  - Tab detection
  - Quote balancing
  - Syntax error reporting

#### ISO Manipulation
- **iso-tools.sh**: Abstraction layer for ISO operations
  - Automatic backend detection
  - Mount/umount support (preferred)
  - Python fallback support
  - Unified extract_iso() and create_iso() functions

- **pyiso.py**: Python-based ISO manipulation
  - Works without root/sudo
  - Docker-friendly
  - Full ISO extraction and creation

#### Additional Tools
- **download-iso.sh**: Robust ISO downloader
  - Retry logic (3 attempts)
  - Checksum verification
  - Progress indicators
  - Mirror support
  - Resume capability

- **check-ubuntu-updates.sh**: Version update checker
  - Queries releases.ubuntu.com
  - 24-hour caching
  - JSON output support
  - Version comparison

- **test-in-vm.sh**: VM testing framework
  - Hyper-V support (PowerShell integration)
  - QEMU/KVM support
  - SSH connectivity testing
  - Automated test execution

- **test-python-fallback.sh**: Python backend tester
  - Validates Python ISO manipulation
  - Docker environment testing
  - Fallback verification

### Profile Collection (11 Total)

#### Core Profiles
1. **minimal-server**: Bare minimum for containers (~700MB RAM)
2. **standard-server**: General-purpose with common tools
3. **web-server**: NGINX, PHP-FPM, Let's Encrypt ready
4. **database-server**: PostgreSQL 14 with optimizations
5. **container-host**: Docker CE, Kubernetes tools

#### Specialized Profiles
6. **security-hardened**: CIS benchmark, encryption, audit logging
7. **hyper-v-optimized**: Integration services, enhanced session
8. **ci-cd-runner**: GitHub Actions runner, Docker-in-Docker
9. **monitoring-server**: Prometheus, Grafana, exporters

#### Example Profiles
10. **example-minimal**: Basic DHCP setup example
11. **example-web-server**: LAMP stack with static IP

### Templates System

#### Base Template
- **autoinstall-base.yaml**: Comprehensive starting point
  - All common configuration sections
  - Extensive comments
  - Best practices embedded

#### Configuration Snippets
1. **network-static.yaml**: Static IP configuration
2. **storage-lvm-encrypted.yaml**: Encrypted LVM setup
3. **packages-development.yaml**: Development tools
4. **packages-monitoring.yaml**: Monitoring agents
5. **security-hardening.yaml**: Security configurations
6. **ssh-keys.yaml**: SSH key management
7. **users-advanced.yaml**: Multi-user setup
8. **post-install-docker.yaml**: Docker installation

## Architecture Decisions

### 1. Native Tools Philosophy
The project exclusively uses tools pre-installed on Linux systems:
- **Primary**: mount, umount, dd, python3
- **No Dependencies**: No yq, jq, or external tools
- **Graceful Degradation**: Automatic fallbacks
- **Universal Compatibility**: Works everywhere

### 2. Validation Strategy
Multi-layered validation approach:
- **Subiquity**: Official Canonical validator (when available)
- **Local Validation**: Python-based fallback
- **Syntax Checking**: YAML validity
- **Integration**: Built into build pipeline

### 3. Error Handling
Robust error management throughout:
- **Set -euo pipefail**: Strict bash error handling
- **Validation**: Pre-flight checks before building
- **Fallbacks**: Multiple methods for each operation
- **User Feedback**: Clear error messages

### 4. Testing Framework
Comprehensive testing approach:
- **Unit Tests**: Individual component validation
- **Integration Tests**: Full pipeline testing
- **VM Testing**: Real-world validation
- **CI/CD**: Automated testing on every commit

## Technical Implementation Details

### ISO Manipulation Flow
1. **Detection**: iso-tools.sh detects available backend
2. **Extraction**: Mount (preferred) or Python extraction
3. **Modification**: Inject autoinstall.yaml and modify boot
4. **Recreation**: genisoimage/mkisofs or Python creation
5. **Validation**: Output verification

### Validation Pipeline
1. **YAML Syntax**: Basic structure validation
2. **Schema Validation**: Required fields check
3. **Subiquity Validation**: Official tool (if available)
4. **Integration**: Automatic in build process

### GitHub Actions Integration
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [master, main]
  pull_request:
  release:
    types: [created]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: NO_COLOR=1 ./test.sh
  
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./bin/build-all
      - uses: actions/upload-artifact@v3
        with:
          path: output/*.iso
```

## Known Limitations

### 1. Docker Environment
- Loop devices not available in containers
- Python fallback handles this automatically
- Full functionality maintained

### 2. Subiquity Dependencies
- Requires Python modules not always available
- Local validation provides sufficient coverage
- Not critical for operation

## Maintenance Guidelines

### Adding New Profiles
1. Create directory: `profiles/new-profile/`
2. Add autoinstall.yaml with #cloud-config header
3. Include comprehensive README.md
4. Validate: `./scripts/validate-autoinstall.sh profiles/new-profile/autoinstall.yaml`
5. Test: `./bin/build-iso --profile new-profile`
6. Document in main README.md

### Updating Ubuntu Versions
1. Check for updates: `./scripts/check-ubuntu-updates.sh`
2. Update .env: `UBUNTU_VERSION=24.04.1`
3. Test all profiles: `./bin/build-all`
4. Update documentation

### Debugging Issues
1. Enable verbose mode: `VERBOSE=1 ./bin/build-iso ...`
2. Check specific backend: `./scripts/iso-tools.sh`
3. Validate profiles: `./scripts/validate-autoinstall.sh ...`
4. Test in VM: `./scripts/test-in-vm.sh ...`

## Extension Opportunities

### Potential Enhancements
1. **Web UI**: Browser-based profile generator
2. **Profile Marketplace**: Community profile sharing
3. **Multi-Architecture**: ARM64 support
4. **Cloud Images**: AWS, Azure, GCP variants
5. **Ansible Integration**: Post-install automation
6. **Monitoring Dashboard**: Build status and metrics

### Integration Points
- **Terraform**: Automated VM provisioning
- **Packer**: Alternative image building
- **Kubernetes**: Automated node provisioning
- **CI/CD Systems**: Jenkins, GitHub Actions

## Security Considerations

### Build-Time Security
- No credentials in Git
- Password hashing enforced
- SSH key preference
- Validation prevents injection

### Runtime Security
- Encrypted storage options
- Firewall configurations
- Security-hardened profile
- Audit logging support

## Performance Optimizations

### Caching Strategy
- ISO downloads cached
- 24-hour update checks
- Reusable extract directories
- Incremental builds possible

### Parallel Processing
- Multiple profiles can build concurrently
- GitHub Actions parallel jobs
- Resource-aware execution

## GitHub Integration

### GitHub Actions Workflow
The project uses GitHub Actions for complete CI/CD automation:

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline
on:
  push: [master, main]
  pull_request:
  release:
    types: [created]
  workflow_dispatch:  # Manual trigger

jobs:
  test:         # Validates code and profiles
  security:     # Scans for security issues
  build:        # Builds ISOs in parallel
  release:      # Creates GitHub releases
```

### GitHub CLI Usage
Common commands for project management:

```bash
# Check workflow status
gh workflow list
gh run list

# Download artifacts
gh run download <run-id>

# Create issues
gh issue create --title "Bug: ..." --body "..."

# Create pull requests
gh pr create --title "Feature: ..." --body "..."

# Release management
gh release create v1.0.0 --title "Release v1.0.0" --notes "..."
```

### Benefits of GitHub Platform
- **Free CI/CD**: GitHub Actions provides generous free tier
- **No Runner Setup**: Managed runners just work
- **Artifact Storage**: Automatic artifact management
- **Release Management**: Integrated release creation
- **Security Scanning**: Built-in security features
- **API Access**: Full automation via GitHub CLI

## Project Philosophy

### Design Principles
1. **Simplicity**: Native tools, no dependencies
2. **Reliability**: Multiple fallbacks, comprehensive testing
3. **Flexibility**: Profiles for every use case
4. **Usability**: Interactive tools, clear documentation
5. **Maintainability**: Clean code, extensive comments

### Success Metrics
- ✅ Zero external dependencies
- ✅ Works in restricted environments
- ✅ Comprehensive test coverage
- ✅ Production-ready profiles
- ✅ Active CI/CD pipeline

## Configuration Management Best Practices

When building server provisioning and configuration systems, ALWAYS follow these industry standards and best practices:

### 1. Server Identity and Role Assignment
- **ALWAYS use metadata/tags** for server identity (cloud-init user-data, VM metadata, instance tags)
- **NEVER use MAC addresses** for role mapping - they're unreliable and hard to manage
- **PREFER DNS-based discovery** - use DNS names or SRV records for service discovery
- **USE predictable naming** - hostnames should indicate role and environment (e.g., `prod-github-01`)

### 2. Configuration Management Approach
- **ALWAYS use pull-based configuration** (Ansible-pull, Chef client, Puppet agent) for security
- **NEVER require inbound SSH** from management servers - servers should pull their config
- **USE GitOps principles** - store all configuration in version control
- **IMPLEMENT idempotency** - configurations should be safe to run multiple times

### 3. Secrets and Credentials
- **ALWAYS use a secrets management tool**:
  - HashiCorp Vault (recommended for on-premise)
  - AWS Secrets Manager / Azure Key Vault (for cloud)
  - Kubernetes Secrets (for container environments)
- **NEVER store secrets in Git** - not even encrypted
- **ROTATE credentials regularly** - implement automatic rotation where possible
- **USE SSH certificates** instead of static SSH keys when possible

### 4. Modern Patterns and Standards

#### Cloud-Init with Metadata (Industry Standard)
```yaml
#cloud-config
# Pass role via user-data or metadata service
runcmd:
  - ROLE=$(curl -s http://169.254.169.254/latest/meta-data/tags/Role)
  - ansible-pull -U https://git.internal/ansible.git -t $ROLE
```

#### Infrastructure as Code Integration
```hcl
# Terraform + Cloud-Init
resource "vsphere_virtual_machine" "server" {
  extra_config = {
    "guestinfo.metadata" = base64encode(jsonencode({
      role        = "github"
      environment = "production"
    }))
  }
}
```

#### Service Discovery
```bash
# DNS SRV records for service discovery
dig SRV _config._tcp.internal.company.com
# Returns: config-01.internal.company.com:443
```

### 5. Best Practices Summary
1. **Metadata-driven** - Use cloud-init metadata, not hardcoded mappings
2. **Pull-based** - Servers fetch their configuration, don't push to them
3. **Secrets in vault** - Never in code or configuration files
4. **Version controlled** - All configs in Git with proper branching
5. **Discoverable** - Use DNS/Consul/etcd for service discovery
6. **Immutable when possible** - Prefer replacing servers over configuring
7. **Auditable** - Log all configuration changes and access

### 6. Implementation Priority
When implementing server provisioning:
1. Start with cloud-init and metadata
2. Add pull-based configuration (Ansible-pull)
3. Integrate secrets management
4. Implement service discovery
5. Add monitoring and alerting
6. Enable audit logging

These practices ensure secure, scalable, and maintainable infrastructure that aligns with industry standards.

## Bootstrap Architecture and Implementation

The project implements a sophisticated two-phase bootstrap architecture to solve the chicken-and-egg problem of infrastructure dependencies:

### Phase 1: Infrastructure Bootstrap
- **Config Server**: Self-contained ISO that sets up the configuration management server without external dependencies
- **Repository Server**: Bootstrap ISO that can use the config server once it exists
- **Manual Process**: These two servers must be deployed manually before automation can begin

### Phase 2: Automated Operations  
- **Role-Based ISOs**: All other servers use minimal ISOs with embedded role metadata
- **Cloud-Init Integration**: Servers identify their role and pull configuration from the config server
- **Ansible-Pull**: No central Ansible server needed - each server configures itself
- **GitOps Workflow**: All configurations stored in Git for version control and auditability

### Key Implementation Details

#### Current Environment (HSC)
- **Hypervisor**: Windows Server 2019 with Hyper-V
- **Network**: F5 BIG-IP for DHCP/DNS
- **Hostnames**: hsc-ctsc-config.health.unm.edu, hsc-ctsc-repository.health.unm.edu
- **No Terraform/Pulumi**: Simple PowerShell scripts for VM deployment

#### Industry Standards Implemented
- **Cloud-Init with Metadata**: Role assignment via cloud-init, not MAC addresses
- **Pull-Based Configuration**: Servers pull their configuration for security
- **Service Discovery**: DNS-based discovery of infrastructure services
- **Secrets Management**: Designed for HashiCorp Vault integration
- **GitOps Principles**: All configuration in version control

### Documentation Structure

The project now includes comprehensive documentation:
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**: Complete technical architecture
- **[docs/BOOTSTRAP-GUIDE.md](docs/BOOTSTRAP-GUIDE.md)**: Detailed bootstrap procedures
- **[docs/DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md)**: Step-by-step deployment
- **[docs/ROLE-DEFINITIONS.md](docs/ROLE-DEFINITIONS.md)**: All available server roles
- **[README.md](README.md)**: Project overview and quick start

## Current Status (Latest Updates)

### ✅ Completed Tasks

1. **Comprehensive Documentation Created**:
   - ✅ [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Complete system architecture
   - ✅ [docs/BOOTSTRAP-GUIDE.md](docs/BOOTSTRAP-GUIDE.md) - Bootstrap procedures
   - ✅ [docs/DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) - Deployment guide
   - ✅ [docs/ROLE-DEFINITIONS.md](docs/ROLE-DEFINITIONS.md) - Server role definitions
   - ✅ [docs/WINDOWS-DEPLOYMENT.md](docs/WINDOWS-DEPLOYMENT.md) - Windows/Hyper-V guide
   - ✅ [docs/GITHUB-RUNNERS.md](docs/GITHUB-RUNNERS.md) - GitHub Actions runner guide
   - ✅ Updated README.md as documentation hub
   - ✅ All documents properly cross-linked

2. **Architecture Decisions Made**:
   - ✅ Two-phase bootstrap approach (infrastructure → automated)
   - ✅ Cloud-init metadata for role assignment (NOT MAC addresses)
   - ✅ Pull-based configuration with ansible-pull
   - ✅ No Terraform/Pulumi - PowerShell scripts for Hyper-V
   - ✅ GitOps principles with version control

3. **Environment Specifics Defined**:
   - Platform: Windows Server 2019 with Hyper-V
   - Network: F5 BIG-IP for DHCP/DNS
   - Config Server: hsc-ctsc-config.health.unm.edu
   - Repository Server: hsc-ctsc-repository.health.unm.edu
   - GitHub Enterprise for Actions runners

4. **GitHub Actions Runner Implementation**:
   - ✅ Complete rewrite of github role for Actions runners (not Gitea)
   - ✅ Enterprise-ready runner deployment with 4 runners per server
   - ✅ Ephemeral runners with security hardening
   - ✅ Comprehensive monitoring and maintenance automation
   - ✅ Interactive registration wizard and management tools
   - ✅ Full documentation and operational procedures

### ✅ Recently Completed (Bootstrap & Deployment)

1. **Profile Directories Created**:
   - ✅ `profiles/config-bootstrap/` - Self-contained config server
   - ✅ `profiles/repository-bootstrap/` - Repository server
   - ✅ `profiles/github-server/` - GitHub Actions runners
   - ✅ `profiles/tools-server/` - Development tools
   - ✅ `profiles/artifacts-server/` - Package repository

2. **Ansible Infrastructure**:
   - ✅ Moved to `/app/ansible/` with proper structure
   - ✅ Created comprehensive roles for all server types
   - ✅ Implemented pull-based configuration

3. **Deployment Automation**:
   - ✅ PowerShell scripts for Windows/Hyper-V
   - ✅ Docker-based ISO building
   - ✅ Role-based ISO generation

### 🚧 Potential Future Enhancements

1. **Advanced Runner Features**:
   - Actions Runner Controller (Kubernetes)
   - GPU-enabled runners for ML workloads
   - Autoscaling based on queue depth
   - Multi-architecture support (ARM64)

2. **Security Enhancements**:
   - HashiCorp Vault integration for secrets
   - SIEM integration for audit logs
   - Compliance scanning automation

3. **Operational Improvements**:
   - Web UI for ISO generation
   - Centralized monitoring dashboard
   - Automated disaster recovery
   - Each ISO embeds its role in metadata

5. **PowerShell Deployment Scripts**:
   ```powershell
   deploy/Deploy-VM.ps1        # Create Hyper-V VM with ISO
   deploy/Build-RoleISO.ps1    # Build ISO for specific role
   deploy/Get-LatestISO.ps1    # Download from repository
   ```

6. **GitHub Actions Updates**:
   - Modify workflows to upload ISOs to repository server
   - Add authentication for repository API
   - Implement versioning and tagging

### 📝 Implementation Notes

**Bootstrap ISOs**:
- Must be completely self-contained
- Config server cannot depend on anything
- Repository server can depend on config server
- Use cloud-init runcmd for inline configuration

**Standard ISOs**:
- Minimal configuration
- Embed role in cloud-init metadata
- Contact config server on first boot
- Run ansible-pull to configure

**Cloud-Init Metadata Structure**:
```yaml
#cloud-config
version: 1
user-data:
  role: github  # This determines server configuration
  config_server: hsc-ctsc-config.health.unm.edu
  environment: production
```

**PowerShell VM Creation**:
```powershell
New-VM -Name "hsc-ctsc-github-01" `
  -MemoryStartupBytes 8GB `
  -Generation 2 `
  -VHDPath "C:\VMs\github-01.vhdx" `
  -VHDSizeBytes 100GB
```

### 🔑 Key Decisions Summary

1. **NO MAC Address Mapping** - Use cloud-init metadata
2. **Pull-Based Config** - ansible-pull, not push
3. **Two-Phase Bootstrap** - Manual infra, then automated
4. **PowerShell for Hyper-V** - No Terraform/Pulumi
5. **Role-Embedded ISOs** - Each ISO knows its role
6. **Self-Hosting** - System can rebuild itself

## Conclusion

The Ubuntu Server Unattended ISO Builder has evolved into a complete infrastructure automation system. It combines ISO building, cloud-init automation, and Ansible configuration management to enable zero-touch server deployments. The bootstrap architecture allows the system to be self-hosting while following industry best practices.

The project successfully demonstrates that complex automation can be achieved using only native Linux tools, making it universally compatible and maintenance-free. With comprehensive documentation, role-based deployments, and a robust bootstrap process, it's ready for production use in enterprise environments.
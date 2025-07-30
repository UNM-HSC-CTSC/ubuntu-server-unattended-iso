# Ubuntu Server Unattended ISO Builder

[![CI/CD Pipeline](https://github.com/jwylesUNM/ubuntu-server-unattended-iso/actions/workflows/ci.yml/badge.svg)](https://github.com/jwylesUNM/ubuntu-server-unattended-iso/actions)
[![GitHub release](https://img.shields.io/github/release/jwylesUNM/ubuntu-server-unattended-iso.svg)](https://github.com/jwylesUNM/ubuntu-server-unattended-iso/releases)
[![License](https://img.shields.io/github/license/jwylesUNM/ubuntu-server-unattended-iso.svg)](LICENSE)

A professional GitHub Actions-powered tool for creating unattended Ubuntu Server installation ISOs with custom configurations. This project automates the process of downloading Ubuntu Server ISOs, injecting autoinstall.yaml configurations, and repackaging them for automated deployments.

## 🚀 Features

- **Automated ISO Creation** - Download Ubuntu Server ISOs and inject custom autoinstall configurations
- **11 Pre-built Profiles** - Ready-to-use configurations for common server deployments
- **Profile Validation** - Built-in validation using Canonical's Subiquity validator
- **Interactive Generator** - Wizard to create custom autoinstall.yaml configurations
- **VM Testing Framework** - Test ISOs in virtual machines (Hyper-V, QEMU/KVM)
- **GitHub Actions CI/CD** - Automated building, testing, and releasing of ISOs
- **GitHub CLI Integration** - Monitor CI/CD workflows and project management
- **Ubuntu Update Checker** - Stay informed about new Ubuntu releases
- **Native Tools Only** - No external dependencies required
- **Python Fallback** - Works in restricted environments (Docker, CI/CD)

## 📋 Quick Start

### Prerequisites

#### System Requirements
- **OS**: Linux (Ubuntu/Debian recommended)
- **Python**: 3.6 or higher
- **Storage**: 5GB free space (for ISO downloads and builds)

#### Required Dependencies
```bash
# Core tools (usually pre-installed on Linux)
bash, wget, curl, python3, mount, umount, dd

# Python packages (for YAML validation)
pyyaml
```

#### Quick Install (Ubuntu/Debian)
```bash
# Option 1: Use the Makefile (recommended)
make install

# Option 2: Manual installation
sudo apt-get update
sudo apt-get install -y wget curl python3 python3-pip make genisoimage
pip3 install -r requirements.txt

# Option 3: Minimal installation
sudo apt-get install -y python3 wget curl
```

#### Verify Dependencies
```bash
# Check if all dependencies are installed
./scripts/test-dependencies.sh
```

**Note**: The project automatically detects available tools and uses:
1. Native `mount`/`umount` for ISO extraction (preferred)
2. Python fallback methods if mount is unavailable
3. `genisoimage`/`mkisofs` for ISO creation (optional but recommended)

### Quick Start (2 minutes)

```bash
# Clone the repository
git clone https://github.com/jwylesUNM/ubuntu-server-unattended-iso.git
cd ubuntu-server-unattended-iso

# Or use GitHub CLI
gh repo clone jwylesUNM/ubuntu-server-unattended-iso
cd ubuntu-server-unattended-iso

# Build your first ISO (Ubuntu will be downloaded automatically)
make build PROFILE=minimal-server

# Your custom ISO is now in output/
ls -la output/*.iso
```

### Alternative Methods

1. **Direct script usage:**
   ```bash
   ./bin/build-iso --profile minimal-server
   ```

2. **Create a custom profile:**
   ```bash
   make generate
   # or: ./bin/generate-autoinstall
   ```

3. **Build with different profile:**
   ```bash
   make build PROFILE=web-server
   make build PROFILE=database-server
   # See profiles/ directory for all options
   ```

## 📁 Project Structure

```
ubuntu-server-unattended-iso/
├── Makefile                 # Main entry point (make install, make build)
├── requirements.txt         # Python dependencies
├── bin/                     # User-facing commands
│   ├── build-iso           # Build single ISO
│   ├── build-all           # Build all profiles
│   └── generate-autoinstall # Interactive profile generator
├── lib/                     # Shared libraries
│   └── iso-tools.sh        # ISO manipulation functions
├── scripts/                 # Internal helper scripts
│   ├── test.sh             # Test suite
│   ├── validate-autoinstall.sh  # Autoinstall validation
│   ├── download-iso.sh      # ISO downloader with retry
│   ├── test-in-vm.sh       # VM testing framework
│   ├── check-ubuntu-updates.sh  # Version update checker
│   └── pyiso.py            # Python ISO builder fallback
├── profiles/                # Server configuration profiles
│   ├── minimal-server/      # Bare minimum installation
│   ├── standard-server/     # General purpose server
│   ├── web-server/         # NGINX web server
│   ├── database-server/    # PostgreSQL database
│   ├── container-host/     # Docker/Kubernetes ready
│   ├── security-hardened/  # CIS benchmark compliant
│   ├── hyper-v-optimized/  # Hyper-V guest tools
│   ├── ci-cd-runner/       # GitHub Actions runner
│   ├── monitoring-server/  # Prometheus & Grafana
│   └── template-secure/    # Secure template with credentials
├── templates/              # Configuration templates
│   ├── autoinstall-base.yaml    # Base template
│   └── snippets/           # Reusable configuration snippets

```

## 🖥️ Available Profiles

### Core Profiles

#### minimal-server
- Absolute minimum packages for a functional server
- DHCP networking, basic tools (curl, wget, vim)
- ~700MB RAM usage, ideal for containers

#### standard-server
- General-purpose server with common tools
- Development tools, monitoring agents
- Good starting point for most deployments

#### web-server
- NGINX web server with PHP-FPM
- Let's Encrypt Certbot for SSL
- Optimized for web hosting

#### database-server
- PostgreSQL 14 database server
- Optimized settings for database workloads
- Automated backups configured

#### container-host
- Docker CE and Docker Compose
- Kubernetes tools (kubectl, kubeadm)
- Container-optimized kernel settings

### Specialized Profiles

#### security-hardened
- CIS Ubuntu benchmark compliance
- Advanced firewall rules (UFW)
- Audit logging and intrusion detection
- Encrypted root partition

#### hyper-v-optimized
- Hyper-V integration services
- Optimized for Hyper-V guests
- Enhanced session mode support

#### ci-cd-runner
- GitHub Actions runner ready
- Docker-in-Docker support
- Build tools and dependencies

#### monitoring-server
- Prometheus metrics collection
- Grafana dashboards
- Node exporter and alertmanager

### Example Profiles

#### example-minimal
- Basic Ubuntu Server installation
- DHCP networking
- Default password: `ubuntu` (change immediately!)

#### example-web-server
- Complete LAMP stack (Apache, MySQL, PHP)
- Static IP configuration example
- Security tools (fail2ban, UFW)

## 🛠️ Creating Custom Profiles

### Method 1: Interactive Generator (Recommended)

```bash
./bin/generate-autoinstall
```

The wizard will guide you through:
- Profile name and description
- Network configuration (DHCP/Static IP)
- User setup (username, password, SSH keys)
- Storage layout (LVM, encryption options)
- Package selection
- Post-installation scripts
- Security settings

### Method 2: Manual Creation

1. Create a new profile directory:
   ```bash
   mkdir -p profiles/my-custom-server
   ```

2. Create `autoinstall.yaml`:
   ```yaml
   #cloud-config
   version: 1
   locale: en_US.UTF-8
   keyboard:
     layout: us
   identity:
     hostname: my-server
     username: admin
     password: $6$rounds=4096$salted$hash  # Use mkpasswd to generate
   # ... additional configuration
   ```

3. Create a README.md documenting your profile

4. Validate your configuration:
   ```bash
   ./scripts/validate-autoinstall.sh profiles/my-custom-server/autoinstall.yaml
   ```

## 🔧 Command Line Options

### build-iso

```bash
./bin/build-iso --profile PROFILE_NAME [options]

Required:
  --profile NAME         Profile name from profiles/ directory

Options:
  --ubuntu-version VER   Ubuntu version (default: 22.04.3)
  --ubuntu-mirror URL    Mirror URL (default: releases.ubuntu.com)
  --no-cache            Force fresh ISO download
  --output-dir DIR      Output directory (default: ./output)
  --skip-validation     Skip autoinstall.yaml validation
  --help                Show help message
```

### Validation Tools

```bash
# Validate a single profile
./scripts/validate-autoinstall.sh profiles/minimal-server/autoinstall.yaml

# Check YAML syntax only
./scripts/validate-yaml-syntax.sh profiles/*/autoinstall.yaml

# Test in a VM
./scripts/test-in-vm.sh output/minimal-server-ubuntu-22.04.3-20240115.iso
```

### Update Checking

```bash
# Check for new Ubuntu versions
./scripts/check-ubuntu-updates.sh

# Check and compare with current version
./scripts/check-ubuntu-updates.sh --compare 22.04.3
```

## 📦 Building Your ISO

### Quick Build (2 minutes)

```bash
# Build with default minimal profile
make build

# Build with a specific profile
make build PROFILE=web-server

# Or use the script directly
./bin/build-iso --profile minimal-server
```

### ISO Output

Your ISO will be created in the `output/` directory:
- Filename: `{profile-name}-ubuntu-{version}-{date}.iso`
- Example: `minimal-server-ubuntu-22.04.3-20240115.iso`
- Size: ~2GB (same as official Ubuntu Server ISO)

### First Build Note

The first build will download the Ubuntu Server ISO (~2GB). This is cached in `downloads/` for future builds.

## 🧪 Testing

### Run Test Suite

```bash
# Full test suite
./test.sh

# Without color output (for CI/CD)
NO_COLOR=1 ./test.sh
```

### VM Testing

```bash
# Test with Hyper-V (Windows)
./scripts/test-in-vm.sh --hypervisor hyperv output/your-iso.iso

# Test with QEMU/KVM (Linux)
./scripts/test-in-vm.sh --hypervisor qemu output/your-iso.iso
```

## 🔒 Security Considerations

1. **Default Passwords**: Example profiles use default passwords. Always change them immediately after installation or use SSH keys.

2. **Password Generation**: Use `mkpasswd` to generate secure password hashes:
   ```bash
   mkpasswd -m sha-512
   ```

3. **SSH Keys**: Prefer SSH key authentication:
   ```yaml
   ssh:
     install-server: true
     authorized-keys:
       - ssh-rsa AAAAB3NzaC1... user@host
   ```

4. **Disk Encryption**: Enable for sensitive deployments:
   ```yaml
   storage:
     layout:
       name: lvm
       encryption:
         password: your-encryption-password
   ```

5. **Network Security**: Configure firewalls appropriately:
   ```yaml
   late-commands:
     - curtin in-target -- ufw enable
     - curtin in-target -- ufw allow ssh
   ```

## 🔧 Configuration

### Environment Variables (.env)

```bash
UBUNTU_VERSION=22.04.3        # Ubuntu version to download
UBUNTU_MIRROR=https://releases.ubuntu.com  # Mirror URL
CACHE_DIR=./downloads         # ISO cache directory
OUTPUT_DIR=./output          # Generated ISO directory
```

### Profile Selection

Profiles can be customized for different deployment scenarios:
- **Development**: Use `standard-server` with development tools
- **Production Web**: Use `web-server` or `security-hardened`
- **Containers**: Use `minimal-server` or `container-host`
- **Databases**: Use `database-server` with appropriate storage

## 🐛 Troubleshooting

### Common Issues

1. **"Loop device support not available"**
   - This is expected in Docker containers
   - The Python fallback will be used automatically

2. **"Autoinstall validation failed"**
   - Run validation directly to see errors:
     ```bash
     ./scripts/validate-autoinstall.sh your-profile/autoinstall.yaml
     ```
   - Check for missing required fields (version, identity)

3. **ISO Download Failures**
   - Check your internet connection
   - Verify the Ubuntu version exists
   - Try a different mirror with `--ubuntu-mirror`

4. **Build Failures**
   - Run the test suite: `./test.sh`
   - Check for missing tools
   - Ensure sufficient disk space

### Debug Mode

```bash
# Enable verbose output
VERBOSE=1 ./bin/build-iso --profile minimal-server

# Test specific components
./scripts/iso-tools.sh  # Test ISO backend detection
./scripts/download-iso.sh --version 22.04.3  # Test downloads
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your profile or enhancement
4. Ensure tests pass: `./test.sh`
5. Submit a merge request

### Profile Contribution Guidelines

- Include comprehensive README.md
- Validate with `validate-autoinstall.sh`
- Test in a VM before submitting
- Follow existing naming conventions
- Document any special requirements

## 📚 Additional Resources

- [Ubuntu Autoinstall Reference](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Subiquity Installer](https://github.com/canonical/subiquity)

## 🔧 GitHub Integration

### GitHub Actions Status
View the latest build status and download artifacts:
- [Actions](https://github.com/jwylesUNM/ubuntu-server-unattended-iso/actions)
- [Latest Release](https://github.com/jwylesUNM/ubuntu-server-unattended-iso/releases/latest)

### Using GitHub CLI

```bash
# Check workflow runs
gh run list
gh run view

# Download artifacts from a specific run
gh run download <run-id>

# Create an issue
gh issue create --title "Feature request: ..." --body "..."

# Create a pull request
gh pr create --title "Add new profile: ..." --body "..."

# Create a new release
gh release create v1.0.0 --title "Version 1.0.0" --generate-notes

# Download ISOs from latest release
gh release download latest
```

### Triggering Builds

```bash
# Manually trigger a workflow run
gh workflow run ci.yml

# Watch the workflow progress
gh run watch
```

## 📄 License

This project is provided as-is for creating Ubuntu Server installation media.

## 💬 Support

For issues or questions:
- Check existing [Issues](../../issues)
- Review the [Wiki](../../wiki) for guides
- Review [CLAUDE.md](CLAUDE.md) for technical architecture details
- Contact the project maintainers
- Use GitHub CLI: `gh issue create` or `gh pr create`
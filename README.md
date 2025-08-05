# Ubuntu Server Unattended ISO Builder

[![CI/CD Pipeline](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/actions/workflows/ci.yml/badge.svg)](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/actions)
[![GitHub release](https://img.shields.io/github/release/UNM-HSC-CTSC/ubuntu-server-unattended-iso.svg)](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/releases)
[![License](https://img.shields.io/github/license/UNM-HSC-CTSC/ubuntu-server-unattended-iso.svg)](LICENSE)

A comprehensive system for creating self-configuring Ubuntu Server installations through custom ISOs. This project combines ISO building, cloud-init automation, and Ansible configuration management to enable zero-touch server deployments.

## 🚀 Key Features

- **Automated ISO Creation** - Build custom Ubuntu Server ISOs with embedded configurations
- **Role-Based Deployments** - Servers automatically configure themselves based on assigned roles
- **Bootstrap Architecture** - Self-hosting infrastructure with config and repository servers
- **CI/CD Integration** - GitHub Actions automatically builds and distributes ISOs
- **Zero Dependencies** - Uses only standard Linux tools, works everywhere
- **Interactive Generator** - Create custom configurations with guided wizard

## 📚 Documentation

- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design and components
- **[Bootstrap Guide](docs/BOOTSTRAP-GUIDE.md)** - Setting up infrastructure from scratch
- **[Deployment Guide](docs/DEPLOYMENT-GUIDE.md)** - Step-by-step deployment procedures
- **[Windows Deployment Guide](docs/WINDOWS-DEPLOYMENT.md)** - Complete guide for Windows Server with Hyper-V
- **[Role Definitions](docs/ROLE-DEFINITIONS.md)** - Available server roles and configurations
- **[Developer Guide](CLAUDE.md)** - Technical details and design decisions

## 🎯 Use Cases

This project is ideal for:
- **Data Centers** - Automated server provisioning at scale
- **DevOps Teams** - Consistent, repeatable deployments
- **Home Labs** - Quick server setup with minimal effort
- **Disaster Recovery** - Rapidly rebuild infrastructure
- **Compliance** - Auditable, version-controlled configurations

## 🚦 Quick Start

### Option 1: Docker (Recommended - No Dependencies)

#### Linux/macOS:
```bash
# Clone the repository
git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
cd ubuntu-server-unattended-iso

# Build ISO using Docker
./docker-build.sh

# Run interactive configuration generator
./docker-build.sh --generate

# Build with custom configuration
./docker-build.sh -- --autoinstall /input/my-config.yaml
```

#### Windows:
```powershell
# Clone the repository
git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
cd ubuntu-server-unattended-iso

# Build ISO using Docker
.\docker-build.ps1

# Run interactive configuration generator
.\docker-build.ps1 -Generate
```

### Option 2: Local Installation

```bash
# Prerequisites: bash, wget, curl, python3
pip3 install pyyaml yamllint

# Build ISO
./bin/ubuntu-iso --autoinstall share/ubuntu-base/autoinstall.yaml

# Create custom configuration
./bin/ubuntu-iso-generate
```

## 🏗️ System Architecture

```
┌─────────────────┐      ┌───────────────────┐     ┌─────────────────┐
│ GitHub Actions  │────▶│ Repository Server │────▶│   Hyper-V Host  │
│ (Build ISOs)    │      │ (Store ISOs)      │     │ (Deploy VMs)    │
└─────────────────┘      └───────────────────┘     └─────────────────┘
                                │                           │
                                ▼                           ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │ Config Server    │◀────│    New VM       │
                        │ (Ansible/Git)    │     │ (Cloud-init)    │
                        └──────────────────┘     └─────────────────┘
```

## 📦 Available Server Roles

- **Config Server** - Central configuration management
- **Repository Server** - ISO and package storage
- **GitHub Server** - On-premise Git hosting (Gitea)
- **Tools Server** - Development and monitoring tools
- **Artifacts Server** - Package repository (Nexus)

See [Role Definitions](docs/ROLE-DEFINITIONS.md) for complete details.

## 🔧 Advanced Usage

### Building Role-Specific ISOs
```bash
# Build ISO for specific role
./bin/ubuntu-iso --role github --output ubuntu-github.iso

# Build with specific Ubuntu version
./bin/ubuntu-iso --version 24.04.2 --role tools
```

### Bootstrap Process
The system uses a two-phase bootstrap approach to solve infrastructure dependencies:

1. **Phase 1**: Manual deployment of config and repository servers
2. **Phase 2**: Automated deployment of all other servers

See [Bootstrap Guide](docs/BOOTSTRAP-GUIDE.md) for detailed instructions.

### CI/CD Integration
```yaml
# GitHub Actions automatically:
- Builds ISOs on commits
- Validates configurations
- Uploads to repository server
- Creates releases
```

## 🛠️ Configuration Examples

### Basic Server
```yaml
#cloud-config
version: 1
identity:
  hostname: myserver
  username: admin
  password: $6$rounds=4096$...
network:
  ethernets:
    ens160:
      dhcp4: true
```

### Role-Based Server
```yaml
#cloud-config
version: 1
user-data:
  role: github
  config_server: config.company.com
  runcmd:
    - ansible-pull -U https://config.company.com/ansible.git -t github
```

## 📁 Project Structure

```
ubuntu-server-unattended-iso/
├── bin/                    # Executable commands
├── lib/                    # Shared libraries
├── share/                  # Data files and examples
├── profiles/              # Server role profiles
├── ansible/               # Ansible playbooks and roles
├── docs/                  # Documentation
├── tests/                 # Test scripts
└── .github/               # CI/CD workflows
```

## 🧪 Testing

```bash
# Run all tests
./test.sh

# Run with CI mode
NO_COLOR=1 ./test.sh

# Test specific component
./tests/test-iso-tools.sh
```

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup
```bash
# Fork and clone
git clone https://github.com/YOUR-USERNAME/ubuntu-server-unattended-iso.git

# Create feature branch
git checkout -b feature/my-feature

# Make changes and test
./test.sh

# Submit pull request
```

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/issues)
- **Discussions**: [GitHub Discussions](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/discussions)
- **Wiki**: [Project Wiki](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/wiki)

## 🌟 Acknowledgments

- Ubuntu Server team for the autoinstall system
- Canonical for Subiquity installer
- Cloud-init project for first-boot automation
- Ansible community for configuration management
- All contributors and users

## 📊 Project Status

- ✅ Core ISO building functionality
- ✅ Role-based server profiles  
- ✅ Bootstrap architecture
- ✅ CI/CD integration
- ✅ Comprehensive documentation
- 🚧 HashiCorp Vault integration (planned)
- 🚧 Web UI for ISO generation (planned)

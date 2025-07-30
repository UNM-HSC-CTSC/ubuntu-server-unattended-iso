# Ubuntu Server Unattended ISO Builder

[![CI/CD Pipeline](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/actions/workflows/ci.yml/badge.svg)](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/actions)
[![GitHub release](https://img.shields.io/github/release/UNM-HSC-CTSC/ubuntu-server-unattended-iso.svg)](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/releases)
[![License](https://img.shields.io/github/license/UNM-HSC-CTSC/ubuntu-server-unattended-iso.svg)](LICENSE)

A professional command-line tool for creating unattended Ubuntu Server installation ISOs with custom configurations. This project automates the process of downloading Ubuntu Server ISOs, injecting autoinstall.yaml configurations, and repackaging them for automated deployments.

## Features

- **Automated ISO Creation** - Download Ubuntu Server ISOs and inject custom autoinstall configurations
- **Interactive Configuration Generator** - Create custom autoinstall.yaml files with guided wizard
- **Multiple Ubuntu Versions** - Support for current and old Ubuntu releases
- **Validation System** - Built-in YAML and autoinstall validation
- **No External Dependencies** - Uses only standard Linux tools
- **Python Fallback** - Works in restricted environments (Docker, CI/CD)

## Quick Start

### Prerequisites

```bash
# Core tools (usually pre-installed on Linux)
bash, wget, curl, python3

# Python packages
pip3 install pyyaml
```

### Installation

```bash
# Clone the repository
git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
cd ubuntu-server-unattended-iso

# Build your first ISO
./bin/ubuntu-iso --autoinstall share/ubuntu-base/autoinstall.yaml

# Or create a custom configuration interactively
./bin/ubuntu-iso-generate
```

## Usage

### Building an ISO

```bash
# Using the base configuration
ubuntu-iso --autoinstall share/ubuntu-base/autoinstall.yaml

# Using a custom configuration
ubuntu-iso --autoinstall my-config.yaml

# Specify Ubuntu version
ubuntu-iso --version 24.04.1 --autoinstall my-config.yaml

# Skip validation (not recommended)
ubuntu-iso --skip-validation --autoinstall my-config.yaml
```

### Creating Custom Configurations

```bash
# Interactive configuration generator
ubuntu-iso-generate

# This will guide you through:
# - Network setup (DHCP/static IP)
# - User account creation
# - SSH key configuration
# - Package selection
# - Storage layout
# - Post-installation scripts
```

### Checking for Ubuntu Updates

```bash
# Check if new Ubuntu versions are available
ubuntu-iso-check-updates
```

## Environment Variables

Create a `.env` file based on `.env.example`:

```bash
# Ubuntu version to download
UBUNTU_VERSION=22.04.5

# Ubuntu mirror (optional)
UBUNTU_MIRROR=https://releases.ubuntu.com

# Cache directory for ISOs
CACHE_DIR=./cache

# Output directory
OUTPUT_DIR=./output
```

## Project Structure

```
ubuntu-server-unattended-iso/
├── bin/                    # Executable commands
│   ├── ubuntu-iso          # Main ISO builder
│   ├── ubuntu-iso-generate # Configuration generator
│   └── ubuntu-iso-check-updates
├── lib/                    # Shared libraries
│   ├── common.sh          # Common functions
│   ├── download.sh        # ISO download logic
│   ├── validate.sh        # Validation functions
│   ├── iso-tools.sh       # ISO manipulation
│   └── pyiso.py           # Python ISO fallback
├── share/                  # Data files
│   ├── ubuntu-base/       # Base configuration
│   └── examples/          # Example configurations
├── tests/                  # Test scripts
└── .github/               # GitHub Actions workflows
```

## Testing

```bash
# Run all tests
./test.sh

# Run tests with CI mode (no colors)
NO_COLOR=1 ./test.sh
```

## How It Works

1. **Download**: Fetches the specified Ubuntu Server ISO
2. **Extract**: Unpacks the ISO contents
3. **Inject**: Adds your autoinstall.yaml configuration
4. **Repackage**: Creates a new bootable ISO
5. **Validate**: Ensures the configuration is valid

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/issues)
- **Discussions**: [GitHub Discussions](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/discussions)

## Acknowledgments

- Ubuntu Server team for the autoinstall system
- Canonical for Subiquity installer
- Community contributors
# Ubuntu Server Unattended ISO Builder

[![CI/CD Pipeline](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/actions/workflows/ci.yml/badge.svg)](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/actions)
[![GitHub release](https://img.shields.io/github/release/UNM-HSC-CTSC/ubuntu-server-unattended-iso.svg)](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/releases)
[![License](https://img.shields.io/github/license/UNM-HSC-CTSC/ubuntu-server-unattended-iso.svg)](LICENSE)

A professional command-line tool for creating unattended Ubuntu Server installation ISOs with custom configurations. This project automates the process of downloading Ubuntu Server ISOs, injecting autoinstall.yaml configurations, and repackaging them for automated deployments.

**LTS First**: We recommend and default to Ubuntu LTS (Long Term Support) versions for stability and extended support. Currently supported LTS versions are 24.04.2, 22.04.5, and 20.04.6. However, you can use any valid Ubuntu Server version by specifying it.

## Features

- **Automated ISO Creation** - Download Ubuntu Server ISOs and inject custom autoinstall configurations
- **Interactive Configuration Generator** - Create custom autoinstall.yaml files with guided wizard
- **Multiple Ubuntu Versions** - Support for current and old Ubuntu releases
- **Validation System** - Built-in YAML and autoinstall validation
- **No External Dependencies** - Uses only standard Linux tools
- **Python Fallback** - Works in restricted environments (Docker, CI/CD)

## Quick Start

### Option 1: Docker (Recommended - No Dependencies)

#### Linux/macOS:

```bash
# Clone the repository
git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
cd ubuntu-server-unattended-iso

# Build ISO using Docker (automatically builds container on first run)
./docker-build.sh

# Or with a custom configuration
mkdir -p input
cp my-autoinstall.yaml input/
./docker-build.sh -- --autoinstall /input/my-autoinstall.yaml

# Run interactive generator
./docker-build.sh --generate
```

#### Windows:

```powershell
# Clone the repository
git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
cd ubuntu-server-unattended-iso

# Build ISO using Docker (PowerShell)
.\docker-build.ps1

# Or using batch file
docker-build.bat

# With custom configuration
Copy-Item my-autoinstall.yaml input\
.\docker-build.ps1 -- --autoinstall /input/my-autoinstall.yaml

# Run interactive generator
.\docker-build.ps1 -Generate
```

**Note**: Ensure Docker Desktop is installed and set to use Linux containers.

### Option 2: Local Installation

#### Prerequisites

```bash
# Core tools (usually pre-installed on Linux)
bash, wget, curl, python3

# Python packages
pip3 install pyyaml yamllint
```

#### Installation

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

# Specify Ubuntu version (LTS recommended)
ubuntu-iso --version 24.04.2 --autoinstall my-config.yaml

# Use previous LTS version
ubuntu-iso --version 22.04.5 --autoinstall my-config.yaml

# Use any Ubuntu version (including non-LTS)
ubuntu-iso --version 23.10.1 --autoinstall my-config.yaml

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
UBUNTU_VERSION=24.04.2

# Ubuntu mirror (optional)
UBUNTU_MIRROR=https://releases.ubuntu.com

# Cache directory for ISOs
CACHE_DIR=./cache

# Output directory
OUTPUT_DIR=./output
```

## Docker Usage

The Docker setup provides a consistent build environment without requiring local dependencies.

### Linux/macOS:

```bash
# Build the Docker image (if needed)
./docker-build.sh --build

# Build ISO with default configuration
./docker-build.sh

# Use custom autoinstall.yaml from input/ directory
./docker-build.sh -- --autoinstall /input/my-config.yaml

# Run interactive configuration generator
./docker-build.sh --generate

# Start a shell in the container for debugging
./docker-build.sh --shell

# Specify Ubuntu version
./docker-build.sh -- --version 22.04.5 --autoinstall /input/my-config.yaml
```

### Windows (PowerShell):

```powershell
# Build the Docker image (if needed)
.\docker-build.ps1 -Build

# Build ISO with default configuration
.\docker-build.ps1

# Use custom autoinstall.yaml from input\ directory
.\docker-build.ps1 -- --autoinstall /input/my-config.yaml

# Run interactive configuration generator
.\docker-build.ps1 -Generate

# Start a shell in the container for debugging
.\docker-build.ps1 -Shell

# Specify Ubuntu version
.\docker-build.ps1 -- --version 22.04.5 --autoinstall /input/my-config.yaml
```

### Docker Volumes

- `./input/` - Place your custom autoinstall.yaml files here
- `./output/` - Generated ISOs will be saved here
- `./cache/` - Downloaded Ubuntu ISOs are cached here

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
├── docker-build.sh        # Docker wrapper script
├── docker-compose.yml     # Docker Compose configuration
├── Dockerfile            # Docker image definition
└── .github/              # GitHub Actions workflows
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
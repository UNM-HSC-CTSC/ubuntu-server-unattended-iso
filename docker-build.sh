#!/bin/bash
# Docker wrapper for Ubuntu ISO Builder
# This script simplifies running the ISO builder in a Docker container

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

# Helper functions
info() {
    echo -e "${YELLOW}→${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1" >&2
    exit 1
}

# Show usage
usage() {
    cat << EOF
Docker wrapper for Ubuntu ISO Builder

Usage: $0 [options] [-- ubuntu-iso-options]

Options:
    --build         Build/rebuild the Docker image
    --no-cache      Build Docker image without cache
    --generate      Run the interactive generator
    --shell         Start a shell in the container
    --help          Show this help message

Examples:
    # Build an ISO using the base configuration
    $0

    # Build with a custom autoinstall.yaml
    $0 -- --autoinstall input/my-config.yaml

    # Run the interactive generator
    $0 --generate

    # Rebuild the Docker image and then build ISO
    $0 --build -- --autoinstall input/my-config.yaml

    # Start a shell for debugging
    $0 --shell

Volume Mounts:
    ./input   → /input   (read-only) - Place your autoinstall.yaml files here
    ./output  → /output  - Generated ISOs will be saved here
    ./cache   → /cache   - Downloaded Ubuntu ISOs are cached here

EOF
    exit 0
}

# Parse arguments
BUILD_IMAGE=false
NO_CACHE=""
GENERATE=false
SHELL=false
ISO_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_IMAGE=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --generate)
            GENERATE=true
            shift
            ;;
        --shell)
            SHELL=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        --)
            shift
            ISO_ARGS=("$@")
            break
            ;;
        *)
            ISO_ARGS+=("$1")
            shift
            ;;
    esac
done

# Change to script directory
cd "$SCRIPT_DIR"

# Create directories if they don't exist
mkdir -p input output cache

# Load .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Build Docker image if requested or if it doesn't exist
if [ "$BUILD_IMAGE" = true ] || ! docker image inspect ubuntu-iso-builder:latest >/dev/null 2>&1; then
    info "Building Docker image..."
    docker-compose build $NO_CACHE builder || error "Failed to build Docker image"
    success "Docker image built successfully"
fi

# Run the appropriate command
if [ "$SHELL" = true ]; then
    info "Starting shell in container..."
    docker-compose run --rm builder /bin/bash
elif [ "$GENERATE" = true ]; then
    info "Starting interactive generator..."
    docker-compose run --rm generator
else
    # Default: run ubuntu-iso with provided arguments
    if [ ${#ISO_ARGS[@]} -eq 0 ]; then
        # No arguments provided, use default
        info "Building ISO with base configuration..."
        docker-compose run --rm builder ubuntu-iso --autoinstall /app/share/ubuntu-base/autoinstall.yaml
    else
        info "Running ubuntu-iso with custom arguments..."
        docker-compose run --rm builder ubuntu-iso "${ISO_ARGS[@]}"
    fi
fi

# Check if ISO was created
if ls output/*.iso >/dev/null 2>&1; then
    success "ISO created successfully!"
    echo
    echo "Output files:"
    ls -lh output/*.iso
fi
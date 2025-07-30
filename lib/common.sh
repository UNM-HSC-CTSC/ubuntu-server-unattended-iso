#!/bin/bash
# Common functions and variables for Ubuntu ISO Builder
# This file is sourced by other scripts, not executed directly

# Strict error handling
set -euo pipefail

# Script locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
SHARE_DIR="${SCRIPT_DIR}/share"

# Default values - can be overridden by environment or .env file
UBUNTU_VERSION="${UBUNTU_VERSION:-24.04.2}"
UBUNTU_MIRROR="${UBUNTU_MIRROR:-https://releases.ubuntu.com}"
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/cache}"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/output}"
AUTOINSTALL_CONFIG="${AUTOINSTALL_CONFIG:-}"

# Load .env file if it exists
if [ -f "${SCRIPT_DIR}/.env" ]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/.env"
fi

# Colors for output (respect NO_COLOR environment variable)
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
fi

# Logging functions
error() {
    echo -e "${RED}Error:${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}Warning:${NC} $1" >&2
}

info() {
    echo -e "${CYAN}Info:${NC} $1"
}

success() {
    echo -e "${GREEN}Success:${NC} $1"
}

debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}Debug:${NC} $1" >&2
    fi
}

# Check if running as root (some operations need it)
check_root() {
    if [ "$EUID" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Create necessary directories
ensure_directories() {
    mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"
    debug "Ensured directories exist: $CACHE_DIR, $OUTPUT_DIR"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Cleanup function for temporary files
cleanup() {
    local temp_dir="${1:-}"
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        debug "Cleaning up temporary directory: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Generate ISO filename
generate_iso_filename() {
    local profile="${1:-ubuntu-base}"
    local date_stamp=$(date +%Y%m%d)
    echo "${profile}-ubuntu-${UBUNTU_VERSION}-${date_stamp}.iso"
}

# Print version information
print_version() {
    local version="${VERSION:-dev}"
    echo "Ubuntu ISO Builder v${version}"
    echo "Copyright (c) 2024 Ubuntu ISO Builder Contributors"
}

# Verify required dependencies
verify_dependencies() {
    local missing_deps=()
    
    # Check required tools
    local required_tools=("wget" "curl" "python3")
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}\nRun 'make install' to install dependencies."
    fi
}
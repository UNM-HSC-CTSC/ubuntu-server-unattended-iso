#!/bin/bash

# Ubuntu ISO Download Script
# Downloads Ubuntu Server ISOs with retry logic and checksum verification

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
UBUNTU_VERSION="${UBUNTU_VERSION:-22.04.3}"
UBUNTU_MIRROR="${UBUNTU_MIRROR:-https://releases.ubuntu.com}"
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/../downloads}"
RETRY_COUNT=3
RETRY_DELAY=5
VERIFY_CHECKSUM=true

# Colors for output (respect NO_COLOR environment variable)
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# Helper functions
error() {
    echo -e "${RED}Error:${NC} $1" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

info() {
    echo -e "${YELLOW}→${NC} $1"
}

progress() {
    echo -e "${BLUE}↓${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [options]

Downloads Ubuntu Server ISO with retry logic and checksum verification.

Options:
    --version VERSION      Ubuntu version (default: $UBUNTU_VERSION)
    --mirror URL          Mirror URL (default: $UBUNTU_MIRROR)
    --cache-dir DIR       Cache directory (default: $CACHE_DIR)
    --no-verify          Skip checksum verification
    --force              Force download even if file exists
    --retry COUNT        Number of retry attempts (default: $RETRY_COUNT)
    --help               Show this help message

Examples:
    $0
    $0 --version 22.04.3
    $0 --version 20.04.6 --mirror https://mirror.example.com
    $0 --force --no-verify

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    local force_download=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                UBUNTU_VERSION="$2"
                shift 2
                ;;
            --mirror)
                UBUNTU_MIRROR="$2"
                shift 2
                ;;
            --cache-dir)
                CACHE_DIR="$2"
                shift 2
                ;;
            --no-verify)
                VERIFY_CHECKSUM=false
                shift
                ;;
            --force)
                force_download=true
                shift
                ;;
            --retry)
                RETRY_COUNT="$2"
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Export for use in functions
    export FORCE_DOWNLOAD=$force_download
}

# Create cache directory
create_cache_dir() {
    if [ ! -d "$CACHE_DIR" ]; then
        info "Creating cache directory: $CACHE_DIR"
        mkdir -p "$CACHE_DIR"
    fi
}

# Check if download tool is available
check_download_tool() {
    if command -v wget >/dev/null 2>&1; then
        DOWNLOAD_TOOL="wget"
    elif command -v curl >/dev/null 2>&1; then
        DOWNLOAD_TOOL="curl"
    else
        error "Neither wget nor curl is available. Please install one of them."
    fi
    
    info "Using $DOWNLOAD_TOOL for downloads"
}

# Download file with retry logic
download_with_retry() {
    local url="$1"
    local output_file="$2"
    local attempt=1
    
    while [ $attempt -le $RETRY_COUNT ]; do
        progress "Download attempt $attempt of $RETRY_COUNT"
        
        if [ "$DOWNLOAD_TOOL" = "wget" ]; then
            if wget -c -t 1 -T 30 --progress=bar:force -O "$output_file" "$url" 2>&1; then
                return 0
            fi
        else
            # curl
            if curl -L -C - --progress-bar -o "$output_file" "$url"; then
                return 0
            fi
        fi
        
        if [ $attempt -lt $RETRY_COUNT ]; then
            info "Download failed. Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        fi
        
        ((attempt++))
    done
    
    return 1
}

# Verify ISO checksum
verify_checksum() {
    local iso_file="$1"
    local iso_name="$(basename "$iso_file")"
    local checksum_url="${UBUNTU_MIRROR}/${UBUNTU_VERSION}/SHA256SUMS"
    local checksum_file="${CACHE_DIR}/SHA256SUMS-${UBUNTU_VERSION}"
    
    info "Downloading checksums..."
    
    # Download checksum file
    if ! download_with_retry "$checksum_url" "$checksum_file.tmp"; then
        rm -f "$checksum_file.tmp"
        info "WARNING: Could not download checksums. Skipping verification."
        return 0
    fi
    
    mv "$checksum_file.tmp" "$checksum_file"
    
    # Extract checksum for our ISO
    local expected_checksum=$(grep "$iso_name" "$checksum_file" 2>/dev/null | awk '{print $1}')
    
    if [ -z "$expected_checksum" ]; then
        info "WARNING: No checksum found for $iso_name. Skipping verification."
        return 0
    fi
    
    info "Verifying checksum..."
    
    # Calculate actual checksum
    local actual_checksum=""
    if command -v sha256sum >/dev/null 2>&1; then
        actual_checksum=$(sha256sum "$iso_file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual_checksum=$(shasum -a 256 "$iso_file" | awk '{print $1}')
    else
        info "WARNING: No SHA256 tool available. Skipping verification."
        return 0
    fi
    
    if [ "$expected_checksum" = "$actual_checksum" ]; then
        success "Checksum verified"
        return 0
    else
        error "Checksum verification failed!
  Expected: $expected_checksum
  Actual:   $actual_checksum"
        return 1
    fi
}

# Download Ubuntu ISO
download_iso() {
    local iso_name="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
    local iso_url="${UBUNTU_MIRROR}/${UBUNTU_VERSION}/${iso_name}"
    local iso_path="${CACHE_DIR}/${iso_name}"
    
    # Check if ISO already exists
    if [ -f "$iso_path" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
        info "ISO already exists: $iso_path"
        
        if [ "$VERIFY_CHECKSUM" = "true" ]; then
            if verify_checksum "$iso_path"; then
                success "Using cached ISO: $iso_name"
                echo "$iso_path"
                return 0
            else
                info "Checksum verification failed. Re-downloading..."
                rm -f "$iso_path"
            fi
        else
            success "Using cached ISO: $iso_name (checksum not verified)"
            echo "$iso_path"
            return 0
        fi
    fi
    
    # Check if URL is accessible
    info "Checking ISO availability..."
    if [ "$DOWNLOAD_TOOL" = "wget" ]; then
        if ! wget --spider -t 1 -T 10 "$iso_url" 2>/dev/null; then
            error "ISO not found at: $iso_url"
        fi
    else
        if ! curl -I -f -s --connect-timeout 10 "$iso_url" >/dev/null; then
            error "ISO not found at: $iso_url"
        fi
    fi
    
    # Download ISO
    info "Downloading Ubuntu ${UBUNTU_VERSION} Server ISO..."
    info "URL: $iso_url"
    info "Destination: $iso_path"
    
    if download_with_retry "$iso_url" "${iso_path}.tmp"; then
        mv "${iso_path}.tmp" "$iso_path"
        success "Download complete"
        
        # Get file size
        local size=""
        if command -v stat >/dev/null 2>&1; then
            # Linux stat
            size=$(stat -c%s "$iso_path" 2>/dev/null || stat -f%z "$iso_path" 2>/dev/null || echo "0")
            size=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "$size bytes")
        fi
        info "File size: $size"
        
        # Verify checksum
        if [ "$VERIFY_CHECKSUM" = "true" ]; then
            if ! verify_checksum "$iso_path"; then
                rm -f "$iso_path"
                error "Checksum verification failed. Deleted corrupt file."
            fi
        fi
        
        echo "$iso_path"
        return 0
    else
        rm -f "${iso_path}.tmp"
        error "Failed to download ISO after $RETRY_COUNT attempts"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    info "Ubuntu ISO Downloader"
    info "Version: $UBUNTU_VERSION"
    info "Mirror: $UBUNTU_MIRROR"
    echo
    
    create_cache_dir
    check_download_tool
    
    ISO_PATH=$(download_iso)
    
    echo
    success "ISO ready: $ISO_PATH"
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
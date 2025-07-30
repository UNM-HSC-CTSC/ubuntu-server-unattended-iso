#!/bin/bash
# Download functions for Ubuntu ISO Builder
# This file is sourced by other scripts, not executed directly

# Source common functions if not already loaded
if [ -z "${COMMON_LOADED:-}" ]; then
    # shellcheck source=./common.sh
    source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
    COMMON_LOADED=true
fi

# Configuration
RETRY_COUNT="${RETRY_COUNT:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

# List available Ubuntu versions
list_available_versions() {
    info "Common Ubuntu Server LTS versions (recommended):"
    echo "  24.04.2 - Noble Numbat LTS (latest LTS)"
    echo "  22.04.5 - Jammy Jellyfish LTS"
    echo "  20.04.6 - Focal Fossa LTS"
    echo ""
    info "You can use any valid Ubuntu Server version."
    echo "For all versions, visit: https://releases.ubuntu.com"
    echo "For older versions, visit: https://old-releases.ubuntu.com"
}

# Validate Ubuntu version exists
validate_ubuntu_version() {
    local version="${1:-$UBUNTU_VERSION}"
    local iso_name="ubuntu-${version}-live-server-amd64.iso"
    
    info "Validating Ubuntu version ${version}..."
    
    # Try current releases first
    local current_url="${UBUNTU_MIRROR}/${version}/${iso_name}"
    if curl --head --silent --fail --location "$current_url" >/dev/null 2>&1; then
        success "Ubuntu ${version} found at releases.ubuntu.com"
        return 0
    fi
    
    # Try old releases
    local old_mirror="https://old-releases.ubuntu.com/releases"
    local old_url="${old_mirror}/${version}/${iso_name}"
    if curl --head --silent --fail --location "$old_url" >/dev/null 2>&1; then
        info "Ubuntu ${version} found at old-releases.ubuntu.com"
        UBUNTU_MIRROR="$old_mirror"
        return 0
    fi
    
    # Version not found
    error "Ubuntu ${version} not found!\n\n$(list_available_versions)"
}

# Download file with retry logic
download_with_retry() {
    local url="$1"
    local output_file="$2"
    local attempts=0
    
    while [ $attempts -lt "$RETRY_COUNT" ]; do
        attempts=$((attempts + 1))
        
        info "Download attempt $attempts of $RETRY_COUNT"
        
        if wget --continue --progress=bar:force --timeout=30 --tries=1 -O "$output_file" "$url"; then
            return 0
        fi
        
        if [ $attempts -lt "$RETRY_COUNT" ]; then
            warning "Download failed, retrying in ${RETRY_DELAY} seconds..."
            sleep "$RETRY_DELAY"
        fi
    done
    
    return 1
}

# Download Ubuntu ISO with caching
download_ubuntu_iso() {
    local version="${1:-$UBUNTU_VERSION}"
    local iso_name="ubuntu-${version}-live-server-amd64.iso"
    local iso_url="${UBUNTU_MIRROR}/${version}/${iso_name}"
    local iso_path="${CACHE_DIR}/${iso_name}"
    local checksum_url="${UBUNTU_MIRROR}/${version}/SHA256SUMS"
    local checksum_path="${CACHE_DIR}/SHA256SUMS-${version}"
    
    # Create cache directory
    mkdir -p "$CACHE_DIR"
    
    # Check if ISO already exists and skip download if cache is valid
    if [ -f "$iso_path" ] && [ "${NO_CACHE:-false}" != "true" ]; then
        info "Using cached ISO: $iso_path"
        
        # Optionally verify checksum of cached file
        if [ "${VERIFY_CHECKSUM:-true}" = "true" ] && verify_iso_checksum "$iso_path" "$version"; then
            success "Cached ISO checksum verified"
        fi
        
        echo "$iso_path"
        return 0
    fi
    
    # Validate version exists before downloading
    validate_ubuntu_version "$version"
    
    # Download checksums first
    if [ "${VERIFY_CHECKSUM:-true}" = "true" ]; then
        info "Downloading checksums..."
        if ! download_with_retry "$checksum_url" "$checksum_path"; then
            warning "Failed to download checksums, continuing without verification"
            VERIFY_CHECKSUM=false
        fi
    fi
    
    # Download ISO
    info "Downloading Ubuntu ${version} ISO..."
    info "URL: $iso_url"
    info "Destination: $iso_path"
    
    if ! download_with_retry "$iso_url" "$iso_path"; then
        rm -f "$iso_path"
        error "Failed to download ISO after $RETRY_COUNT attempts"
    fi
    
    # Verify checksum
    if [ "${VERIFY_CHECKSUM:-true}" = "true" ]; then
        if verify_iso_checksum "$iso_path" "$version"; then
            success "ISO checksum verified"
        else
            rm -f "$iso_path"
            error "ISO checksum verification failed"
        fi
    fi
    
    success "Downloaded ISO to $iso_path"
    echo "$iso_path"
}

# Verify ISO checksum
verify_iso_checksum() {
    local iso_path="$1"
    local version="${2:-$UBUNTU_VERSION}"
    local iso_name=$(basename "$iso_path")
    local checksum_path="${CACHE_DIR}/SHA256SUMS-${version}"
    
    if [ ! -f "$checksum_path" ]; then
        warning "Checksum file not found, skipping verification"
        return 0
    fi
    
    info "Verifying ISO checksum..."
    
    # Extract expected checksum for our ISO
    local expected_checksum
    expected_checksum=$(grep "$iso_name" "$checksum_path" | awk '{print $1}')
    
    if [ -z "$expected_checksum" ]; then
        warning "No checksum found for $iso_name"
        return 1
    fi
    
    # Calculate actual checksum
    local actual_checksum
    actual_checksum=$(sha256sum "$iso_path" | awk '{print $1}')
    
    if [ "$expected_checksum" = "$actual_checksum" ]; then
        return 0
    else
        error "Checksum mismatch!\nExpected: $expected_checksum\nActual: $actual_checksum"
        return 1
    fi
}

# Clean old ISOs from cache
clean_iso_cache() {
    local keep_days="${1:-30}"
    
    info "Cleaning ISOs older than $keep_days days from cache..."
    
    if [ -d "$CACHE_DIR" ]; then
        find "$CACHE_DIR" -name "*.iso" -type f -mtime +$keep_days -delete
        find "$CACHE_DIR" -name "SHA256SUMS-*" -type f -mtime +$keep_days -delete
        success "Cache cleaned"
    fi
}
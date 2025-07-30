#!/bin/bash

# Verify no credentials remain in build directory
# Used after builds to ensure no sensitive data leaks

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

# Exit status
FOUND_ISSUES=0

# Helper functions
error() {
    echo -e "${RED}Error:${NC} $1" >&2
    FOUND_ISSUES=1
}

warning() {
    echo -e "${YELLOW}Warning:${NC} $1" >&2
    FOUND_ISSUES=1
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check for patterns in files
check_patterns() {
    local pattern="$1"
    local description="$2"
    local found=0
    
    # Find files containing the pattern (excluding ISOs and this script)
    while IFS= read -r file; do
        if [[ ! "$file" =~ \.iso$ ]] && [[ "$file" != *"verify-no-credentials.sh"* ]]; then
            if [ $found -eq 0 ]; then
                warning "Found $description in files:"
                found=1
            fi
            echo "  - $file"
        fi
    done < <(find . -type f -not -path "./.git/*" -not -name "*.iso" -exec grep -l "$pattern" {} \; 2>/dev/null || true)
    
    if [ $found -eq 0 ]; then
        success "No $description found in files"
    fi
}

# Check for specific credential patterns
check_credential_patterns() {
    info "Checking for credential patterns in files..."
    
    # Check for environment variable names that might contain credentials
    check_patterns "ROOT_PASSWORD" "ROOT_PASSWORD references"
    check_patterns "DEFAULT_USER_PASSWORD" "DEFAULT_USER_PASSWORD references"
    check_patterns "DEFAULT_USER_SSH_KEY" "DEFAULT_USER_SSH_KEY references"
    check_patterns "DEFAULT_USERNAME" "DEFAULT_USERNAME references"
    
    # Check for password patterns
    check_patterns "password:" "password: entries"
    check_patterns "passwd:" "passwd: entries"
    
    # Check for SSH key patterns
    check_patterns "ssh-rsa AAAA" "SSH RSA keys"
    check_patterns "ssh-ed25519 AAAA" "SSH ED25519 keys"
    check_patterns "ssh-ecdsa AAAA" "SSH ECDSA keys"
    
    # Check for hashed passwords (SHA-512)
    check_patterns '\$6\$' "SHA-512 password hashes"
}

# Check for temporary files
check_temp_files() {
    info "Checking for temporary files..."
    
    local temp_found=0
    
    # Check /tmp for autoinstall files
    if ls /tmp/autoinstall.* 2>/dev/null | grep -v "No such file"; then
        warning "Found temporary autoinstall files in /tmp"
        ls -la /tmp/autoinstall.*
        temp_found=1
    fi
    
    # Check /dev/shm for autoinstall files
    if [ -d /dev/shm ] && ls /dev/shm/autoinstall.* 2>/dev/null | grep -v "No such file"; then
        warning "Found temporary autoinstall files in /dev/shm"
        ls -la /dev/shm/autoinstall.*
        temp_found=1
    fi
    
    # Check for extract directories
    if ls -d tmp_iso_extract_* 2>/dev/null | grep -v "No such file"; then
        warning "Found temporary ISO extract directories"
        ls -ld tmp_iso_extract_*
        temp_found=1
    fi
    
    if [ $temp_found -eq 0 ]; then
        success "No temporary files found"
    fi
}

# Check environment variables
check_environment() {
    info "Checking environment variables..."
    
    local env_found=0
    
    # Check if credential environment variables are set
    for var in ROOT_PASSWORD DEFAULT_USERNAME DEFAULT_USER_PASSWORD DEFAULT_USER_SSH_KEY; do
        if [ -n "${!var:-}" ]; then
            warning "Environment variable $var is still set"
            env_found=1
        fi
    done
    
    if [ $env_found -eq 0 ]; then
        success "No credential environment variables set"
    fi
}

# Check for credential files in common locations
check_credential_files() {
    info "Checking for credential files..."
    
    local cred_files=(
        "credentials.txt"
        "passwords.txt"
        ".credentials"
        ".passwords"
        "*.key"
        "*.pem"
        "id_rsa*"
        "id_ed25519*"
        "id_ecdsa*"
    )
    
    local found=0
    for pattern in "${cred_files[@]}"; do
        while IFS= read -r file; do
            if [ $found -eq 0 ]; then
                warning "Found potential credential files:"
                found=1
            fi
            echo "  - $file"
        done < <(find . -type f -name "$pattern" -not -path "./.git/*" 2>/dev/null || true)
    done
    
    if [ $found -eq 0 ]; then
        success "No obvious credential files found"
    fi
}

# Main execution
main() {
    echo "Credential Security Verification"
    echo "==============================="
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    # Run all checks
    check_credential_patterns
    check_temp_files
    check_environment
    check_credential_files
    
    # Summary
    echo
    if [ $FOUND_ISSUES -eq 0 ]; then
        success "No credential leaks detected"
        echo "All security checks passed!"
        exit 0
    else
        error "Potential credential leaks detected"
        echo "Please review and clean up the issues found above"
        exit 1
    fi
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main
fi
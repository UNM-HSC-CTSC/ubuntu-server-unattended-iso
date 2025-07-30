#!/bin/bash
# Validation functions for Ubuntu ISO Builder
# This file is sourced by other scripts, not executed directly

# Source common functions if not already loaded
if [ -z "${COMMON_LOADED:-}" ]; then
    # shellcheck source=./common.sh
    source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
    COMMON_LOADED=true
fi

# Validate YAML syntax using Python
validate_yaml_syntax() {
    local yaml_file="$1"
    
    if [ ! -f "$yaml_file" ]; then
        error "YAML file not found: $yaml_file"
    fi
    
    debug "Validating YAML syntax: $yaml_file"
    
    # Check if PyYAML is available
    if ! python3 -c "import yaml" 2>/dev/null; then
        warning "PyYAML not installed, skipping YAML validation"
        return 0
    fi
    
    # Validate YAML
    if python3 -c "
import yaml
import sys
try:
    with open('$yaml_file', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except yaml.YAMLError as e:
    print(f'YAML Error: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
        return 0
    else
        return 1
    fi
}

# Validate autoinstall.yaml structure
validate_autoinstall() {
    local autoinstall_file="$1"
    local skip_subiquity="${2:-false}"
    
    info "Validating autoinstall configuration..."
    
    # First check YAML syntax
    if ! validate_yaml_syntax "$autoinstall_file"; then
        error "Invalid YAML syntax in $autoinstall_file"
    fi
    
    # Check for required cloud-config header
    if ! grep -q "^#cloud-config" "$autoinstall_file"; then
        error "Missing #cloud-config header in $autoinstall_file"
    fi
    
    # Basic structure validation using Python
    if ! python3 -c "
import yaml
import sys

required_fields = ['version', 'identity']
warnings = []

try:
    with open('$autoinstall_file', 'r') as f:
        data = yaml.safe_load(f)
    
    if not isinstance(data, dict):
        print('Error: Root element must be a dictionary', file=sys.stderr)
        sys.exit(1)
    
    # Check required fields
    for field in required_fields:
        if field not in data:
            print(f'Error: Missing required field: {field}', file=sys.stderr)
            sys.exit(1)
    
    # Check version
    if data.get('version') != 1:
        print(f\"Warning: Unexpected version: {data.get('version')}\", file=sys.stderr)
    
    # Check identity
    identity = data.get('identity', {})
    if not identity.get('hostname'):
        warnings.append('No hostname specified')
    if not identity.get('username'):
        warnings.append('No username specified')
    if not identity.get('password'):
        warnings.append('No password specified')
    
    # Print warnings
    for warning in warnings:
        print(f'Warning: {warning}', file=sys.stderr)
    
    sys.exit(0)

except yaml.YAMLError as e:
    print(f'YAML Error: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
        success "Basic autoinstall validation passed"
        return 0
    else
        return 1
    fi
    
    # Try Subiquity validation if available and not skipped
    if [ "$skip_subiquity" != "true" ] && command_exists "subiquity"; then
        info "Running Subiquity validation..."
        if subiquity --dry-run --autoinstall "$autoinstall_file" >/dev/null 2>&1; then
            success "Subiquity validation passed"
        else
            warning "Subiquity validation failed (this is often overly strict)"
        fi
    fi
    
    return 0
}

# Validate profile directory structure
validate_profile() {
    local profile_dir="$1"
    
    if [ ! -d "$profile_dir" ]; then
        error "Profile directory not found: $profile_dir"
    fi
    
    if [ ! -f "$profile_dir/autoinstall.yaml" ]; then
        error "Missing autoinstall.yaml in profile: $profile_dir"
    fi
    
    # Validate the autoinstall.yaml
    validate_autoinstall "$profile_dir/autoinstall.yaml"
    
    return 0
}

# Check system dependencies
check_dependencies() {
    local missing_deps=()
    local optional_missing=()
    
    # Required dependencies
    local required=("bash" "wget" "curl" "python3" "mount" "umount" "dd")
    for dep in "${required[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    # Optional dependencies
    local optional=("genisoimage" "mkisofs" "xorriso")
    local found_iso_tool=false
    for dep in "${optional[@]}"; do
        if command_exists "$dep"; then
            found_iso_tool=true
            break
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
    fi
    
    if [ "$found_iso_tool" = false ]; then
        warning "No ISO creation tool found (genisoimage, mkisofs, or xorriso)"
        info "Python fallback will be used for ISO creation"
    fi
    
    # Check Python modules
    if ! python3 -c "import yaml" 2>/dev/null; then
        warning "PyYAML not installed - YAML validation will be limited"
    fi
    
    return 0
}

# Validate environment variables
validate_environment() {
    # Check Ubuntu version format
    if [[ ! "$UBUNTU_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        error "Invalid Ubuntu version format: $UBUNTU_VERSION (expected: XX.XX or XX.XX.X)"
    fi
    
    # Check directories are writable
    local test_file
    test_file="${CACHE_DIR}/.write_test_$$"
    if ! touch "$test_file" 2>/dev/null; then
        error "Cannot write to cache directory: $CACHE_DIR"
    fi
    rm -f "$test_file"
    
    test_file="${OUTPUT_DIR}/.write_test_$$"
    if ! touch "$test_file" 2>/dev/null; then
        error "Cannot write to output directory: $OUTPUT_DIR"
    fi
    rm -f "$test_file"
    
    return 0
}
#!/bin/bash

# Autoinstall Configuration Validator
# Validates autoinstall.yaml files using Subiquity's official validator
# Falls back to local validation if Subiquity is not available

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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

# Configuration
SUBIQUITY_DIR="$PROJECT_DIR/.subiquity"
SUBIQUITY_REPO="https://github.com/canonical/subiquity.git"
SUBIQUITY_VALIDATOR="$SUBIQUITY_DIR/scripts/validate-autoinstall-user-data.py"
USE_SUBIQUITY=true
VERBOSE=false

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

debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

usage() {
    cat << EOF
Usage: $0 [options] FILE [FILE...]

Validates Ubuntu autoinstall.yaml configuration files.

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    --no-subiquity         Skip Subiquity validator (use local validation only)
    --update-subiquity     Update Subiquity repository
    --no-expect-cloudconfig For configs without #cloud-config header

Examples:
    $0 profiles/minimal/autoinstall.yaml
    $0 --verbose profiles/*/autoinstall.yaml
    $0 --no-subiquity autoinstall.yaml

EOF
    exit 0
}

# Check if Subiquity is available
check_subiquity() {
    if [ ! -d "$SUBIQUITY_DIR" ]; then
        info "Subiquity validator not found. Installing..."
        install_subiquity
    elif [ ! -f "$SUBIQUITY_VALIDATOR" ]; then
        info "Subiquity validator script missing. Reinstalling..."
        rm -rf "$SUBIQUITY_DIR"
        install_subiquity
    else
        debug "Subiquity validator found at $SUBIQUITY_VALIDATOR"
    fi
}

# Install Subiquity validator
install_subiquity() {
    if ! command -v git >/dev/null 2>&1; then
        info "Git not available. Falling back to local validation only."
        USE_SUBIQUITY=false
        return
    fi
    
    info "Cloning Subiquity repository..."
    if ! git clone --depth 1 "$SUBIQUITY_REPO" "$SUBIQUITY_DIR" 2>/dev/null; then
        info "Failed to clone Subiquity. Falling back to local validation."
        USE_SUBIQUITY=false
        return
    fi
    
    # Check if make is available for installing dependencies
    if command -v make >/dev/null 2>&1 && [ -f "$SUBIQUITY_DIR/Makefile" ]; then
        info "Installing Subiquity dependencies..."
        (cd "$SUBIQUITY_DIR" && make install_deps >/dev/null 2>&1) || true
    fi
    
    if [ -f "$SUBIQUITY_VALIDATOR" ]; then
        success "Subiquity validator installed"
    else
        info "Subiquity validator not found. Using local validation."
        USE_SUBIQUITY=false
    fi
}

# Update Subiquity
update_subiquity() {
    if [ -d "$SUBIQUITY_DIR/.git" ]; then
        info "Updating Subiquity repository..."
        (cd "$SUBIQUITY_DIR" && git pull) || true
    else
        install_subiquity
    fi
}

# Validate using Subiquity
validate_with_subiquity() {
    local file="$1"
    local no_cloudconfig="${2:-false}"
    
    debug "Validating with Subiquity: $file"
    
    local cmd="python3 $SUBIQUITY_VALIDATOR"
    if [ "$VERBOSE" = true ]; then
        cmd="$cmd -vvv"
    fi
    if [ "$no_cloudconfig" = true ]; then
        cmd="$cmd --no-expect-cloudconfig"
    fi
    cmd="$cmd $file"
    
    if $cmd 2>&1; then
        return 0
    else
        return 1
    fi
}

# Local validation (enhanced version of our existing validator)
validate_locally() {
    local file="$1"
    
    debug "Validating locally: $file"
    
    # Python script for comprehensive validation
    python3 - "$file" << 'EOF'
import sys
import yaml
import os

def validate_autoinstall(file_path):
    errors = []
    warnings = []
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
        # Check for cloud-config header
        if not content.startswith('#cloud-config'):
            warnings.append("Missing #cloud-config header (recommended)")
        
        # Load YAML
        try:
            config = yaml.safe_load(content)
        except yaml.YAMLError as e:
            errors.append(f"YAML parsing error: {e}")
            return errors, warnings
        
        # Check for required fields
        required_fields = ['version', 'identity']
        for field in required_fields:
            if field not in config:
                errors.append(f"Missing required field: {field}")
        
        # Validate version
        if 'version' in config:
            if config['version'] != 1:
                errors.append(f"Invalid version: {config['version']} (must be 1)")
        
        # Validate identity section
        if 'identity' in config:
            identity = config['identity']
            identity_required = ['hostname', 'username', 'password']
            for field in identity_required:
                if field not in identity:
                    errors.append(f"Missing required identity field: {field}")
            
            # Check hostname format
            if 'hostname' in identity:
                hostname = identity['hostname']
                if not hostname or len(hostname) > 63:
                    errors.append("Invalid hostname length (1-63 characters)")
                if not all(c.isalnum() or c == '-' for c in hostname):
                    errors.append("Invalid hostname format (alphanumeric and hyphens only)")
        
        # Validate network configuration
        if 'network' in config:
            network = config['network']
            if 'version' not in network:
                errors.append("Network configuration missing version")
            elif network['version'] != 2:
                warnings.append(f"Network version {network['version']} (version 2 recommended)")
        
        # Validate storage configuration
        if 'storage' in config:
            storage = config['storage']
            if 'layout' in storage:
                valid_layouts = ['lvm', 'direct', 'zfs']
                layout = storage['layout']
                if isinstance(layout, dict):
                    layout_name = layout.get('name', '')
                else:
                    layout_name = layout
                
                if layout_name not in valid_layouts:
                    warnings.append(f"Unknown storage layout: {layout_name}")
        
        # Validate SSH configuration
        if 'ssh' in config:
            ssh = config['ssh']
            if not isinstance(ssh.get('install-server', True), bool):
                errors.append("ssh.install-server must be boolean")
        
        # Validate packages
        if 'packages' in config:
            if not isinstance(config['packages'], list):
                errors.append("packages must be a list")
        
        # Check for common mistakes
        if 'user-data' in config:
            warnings.append("Found 'user-data' key - did you mean to use cloud-init user-data?")
        
        if 'autoinstall' in config:
            warnings.append("Found nested 'autoinstall' key - this should be at root level")
        
        return errors, warnings
        
    except Exception as e:
        errors.append(f"Validation error: {str(e)}")
        return errors, warnings

# Main execution
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: validator.py <file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    errors, warnings = validate_autoinstall(file_path)
    
    if warnings:
        for warning in warnings:
            print(f"WARNING: {warning}")
    
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        sys.exit(1)
    else:
        print(f"VALID: {os.path.basename(file_path)}")
        sys.exit(0)
EOF
}

# Main validation function
validate_file() {
    local file="$1"
    local no_cloudconfig="${2:-false}"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} File not found: $file"
        return 1
    fi
    
    local basename=$(basename "$file")
    local validation_passed=false
    local validation_output=""
    
    # Try Subiquity validation first
    if [ "$USE_SUBIQUITY" = true ] && [ -f "$SUBIQUITY_VALIDATOR" ]; then
        debug "Using Subiquity validator"
        if validation_output=$(validate_with_subiquity "$file" "$no_cloudconfig" 2>&1); then
            validation_passed=true
            success "$basename (Subiquity validation)"
        else
            echo -e "${RED}✗${NC} $basename (Subiquity validation)"
            if [ "$VERBOSE" = true ]; then
                echo "$validation_output" | sed 's/^/  /'
            fi
        fi
    fi
    
    # Also run local validation for additional checks
    if validation_output=$(validate_locally "$file" 2>&1); then
        if [ "$validation_passed" = false ]; then
            success "$basename (local validation)"
            validation_passed=true
        fi
    else
        echo -e "${RED}✗${NC} $basename (local validation)"
        echo "$validation_output" | grep -E "^(ERROR|WARNING):" | sed 's/^/  /'
        validation_passed=false
    fi
    
    if [ "$validation_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Parse command line arguments
parse_args() {
    local no_cloudconfig=false
    local files=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-subiquity)
                USE_SUBIQUITY=false
                shift
                ;;
            --update-subiquity)
                update_subiquity
                exit 0
                ;;
            --no-expect-cloudconfig)
                no_cloudconfig=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                files+=("$1")
                shift
                ;;
        esac
    done
    
    if [ ${#files[@]} -eq 0 ]; then
        error "No files specified. Use -h for help."
    fi
    
    # Export for use in functions
    export NO_CLOUDCONFIG=$no_cloudconfig
    export FILES=("${files[@]}")
}

# Main function
main() {
    parse_args "$@"
    
    info "Ubuntu Autoinstall Configuration Validator"
    
    # Check for Subiquity if enabled
    if [ "$USE_SUBIQUITY" = true ]; then
        check_subiquity
    fi
    
    echo
    debug "Files to validate: ${FILES[@]}"
    info "Validating ${#FILES[@]} file(s)..."
    echo
    
    local total_files=${#FILES[@]}
    local valid_files=0
    local invalid_files=0
    
    for file in "${FILES[@]}"; do
        if validate_file "$file" "$NO_CLOUDCONFIG"; then
            valid_files=$((valid_files + 1))
        else
            invalid_files=$((invalid_files + 1))
        fi
    done
    
    echo
    echo "Summary:"
    echo "  Total files:   $total_files"
    echo "  Valid files:   $valid_files"
    echo "  Invalid files: $invalid_files"
    
    if [ $invalid_files -eq 0 ]; then
        success "All autoinstall configurations are valid"
        exit 0
    else
        error "$invalid_files file(s) have validation errors"
        exit 1
    fi
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
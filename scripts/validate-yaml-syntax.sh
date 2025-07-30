#!/bin/bash

# YAML Validation Script
# Uses Python to validate YAML files without external dependencies

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output (respect NO_COLOR environment variable)
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

usage() {
    cat << EOF
Usage: $0 FILE [FILE...]

Validates YAML file syntax using Python.

Arguments:
    FILE    One or more YAML files to validate

Examples:
    $0 autoinstall.yaml
    $0 profiles/*/autoinstall.yaml

EOF
    exit 0
}

# Check if Python is available
check_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required but not installed"
    fi
    
    # Check if PyYAML is available
    if ! python3 -c "import yaml" 2>/dev/null; then
        info "PyYAML not found. Installing..."
        if command -v pip3 >/dev/null 2>&1; then
            pip3 install --user pyyaml >/dev/null 2>&1 || true
        fi
        
        # Try again with built-in yaml if available
        if ! python3 -c "import yaml" 2>/dev/null; then
            # Use basic YAML validation without PyYAML
            USE_BASIC_VALIDATION=true
        else
            USE_BASIC_VALIDATION=false
        fi
    else
        USE_BASIC_VALIDATION=false
    fi
}

# Validate YAML file
validate_yaml() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} File not found: $file"
        return 1
    fi
    
    # Python script for YAML validation
    local python_script='
import sys
import os

file_path = sys.argv[1]

try:
    # Try to use PyYAML if available
    import yaml
    
    with open(file_path, "r") as f:
        # Load all documents in the file
        documents = list(yaml.safe_load_all(f))
        
    # Check if it'\''s a valid autoinstall configuration
    if len(documents) > 0:
        doc = documents[0]
        
        # Check for cloud-config header
        with open(file_path, "r") as f:
            first_line = f.readline().strip()
            if not first_line.startswith("#cloud-config") and "autoinstall" in file_path.lower():
                print("WARNING: Missing #cloud-config header (recommended for autoinstall files)")
        
        # Check for required autoinstall fields
        if "autoinstall" in file_path.lower():
            required_fields = ["version", "identity"]
            missing_fields = []
            
            for field in required_fields:
                if field not in doc:
                    missing_fields.append(field)
            
            if missing_fields:
                print(f"WARNING: Missing recommended fields: {', '.join(missing_fields)}")
    
    print(f"VALID: {os.path.basename(file_path)}")
    sys.exit(0)
    
except yaml.YAMLError as e:
    print(f"YAML ERROR in {os.path.basename(file_path)}:")
    print(f"  {str(e)}")
    if hasattr(e, "problem_mark"):
        mark = e.problem_mark
        print(f"  Line {mark.line + 1}, Column {mark.column + 1}")
    sys.exit(1)
    
except ImportError:
    # Fallback: Basic syntax checking without PyYAML
    import re
    
    with open(file_path, "r") as f:
        content = f.read()
    
    # Basic syntax checks
    errors = []
    
    # Check for tabs (YAML doesn'\''t allow tabs for indentation)
    if "\t" in content:
        for i, line in enumerate(content.splitlines(), 1):
            if "\t" in line:
                errors.append(f"Line {i}: Contains tab character (use spaces)")
                break
    
    # Check for basic structure
    lines = content.splitlines()
    for i, line in enumerate(lines, 1):
        # Check for common syntax errors
        if line.strip() and not line.startswith("#"):
            # Check for missing space after colon
            if re.search(r"[^:]:(?![\s/]|$)", line):
                errors.append(f"Line {i}: Missing space after colon")
            
            # Check for unbalanced quotes
            single_quotes = line.count("'\''")
            double_quotes = line.count('\"')
            if single_quotes % 2 != 0:
                errors.append(f"Line {i}: Unbalanced single quotes")
            if double_quotes % 2 != 0:
                errors.append(f"Line {i}: Unbalanced double quotes")
    
    if errors:
        print(f"SYNTAX ERRORS in {os.path.basename(file_path)}:")
        for error in errors[:5]:  # Show first 5 errors
            print(f"  {error}")
        if len(errors) > 5:
            print(f"  ... and {len(errors) - 5} more errors")
        sys.exit(1)
    else:
        print(f"VALID (basic check): {os.path.basename(file_path)}")
        sys.exit(0)

except Exception as e:
    print(f"ERROR validating {os.path.basename(file_path)}: {str(e)}")
    sys.exit(1)
'
    
    # Run Python validation
    if python3 -c "$python_script" "$file" 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        usage
    fi
    
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
    fi
    
    check_python
    
    local total_files=0
    local valid_files=0
    local invalid_files=0
    
    info "Validating YAML files..."
    echo
    
    for file in "$@"; do
        ((total_files++))
        if validate_yaml "$file"; then
            ((valid_files++))
        else
            ((invalid_files++))
        fi
    done
    
    echo
    echo "Summary:"
    echo "  Total files:   $total_files"
    echo "  Valid files:   $valid_files"
    echo "  Invalid files: $invalid_files"
    
    if [ $invalid_files -eq 0 ]; then
        success "All files are valid"
        exit 0
    else
        error "$invalid_files file(s) have errors"
        exit 1
    fi
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
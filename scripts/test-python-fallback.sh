#!/bin/bash

# Test Python Fallback for ISO Manipulation
# Verifies that Python-based ISO manipulation works correctly

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
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

# Test directory
TEST_DIR="/tmp/python-fallback-test-$$"
mkdir -p "$TEST_DIR"

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Create a test ISO using Python
create_test_iso() {
    info "Creating test ISO with Python..."
    
    # Create test content
    mkdir -p "$TEST_DIR/source/test"
    echo "Test file content" > "$TEST_DIR/source/test/file.txt"
    echo "Another test" > "$TEST_DIR/source/test.txt"
    
    # Create ISO using Python
    python3 "$SCRIPT_DIR/pyiso.py" create "$TEST_DIR/source" "$TEST_DIR/test.iso" "Test ISO" || error "Failed to create ISO"
    
    if [ -f "$TEST_DIR/test.iso" ]; then
        success "Test ISO created: $(du -h "$TEST_DIR/test.iso" | cut -f1)"
    else
        error "ISO file not created"
    fi
}

# Extract ISO using Python
extract_test_iso() {
    info "Extracting ISO with Python..."
    
    mkdir -p "$TEST_DIR/extracted"
    
    # Extract using Python
    python3 "$SCRIPT_DIR/pyiso.py" extract "$TEST_DIR/test.iso" "$TEST_DIR/extracted" || error "Failed to extract ISO"
    
    # Verify extraction
    if [ -f "$TEST_DIR/extracted/test/file.txt" ]; then
        local content=$(cat "$TEST_DIR/extracted/test/file.txt")
        if [ "$content" = "Test file content" ]; then
            success "ISO extracted correctly"
        else
            error "Extracted file content mismatch"
        fi
    else
        error "Expected file not found in extraction"
    fi
}

# Test with actual Ubuntu ISO if available
test_ubuntu_iso() {
    info "Testing with Ubuntu ISO (if available)..."
    
    # Look for cached Ubuntu ISO
    local ubuntu_iso=""
    if [ -d "$PROJECT_DIR/downloads" ]; then
        ubuntu_iso=$(find "$PROJECT_DIR/downloads" -name "ubuntu-*.iso" -type f | head -1)
    fi
    
    if [ -z "$ubuntu_iso" ]; then
        info "No Ubuntu ISO found in downloads/, skipping Ubuntu ISO test"
        return
    fi
    
    info "Found Ubuntu ISO: $(basename "$ubuntu_iso")"
    
    # Extract Ubuntu ISO
    mkdir -p "$TEST_DIR/ubuntu"
    python3 "$SCRIPT_DIR/pyiso.py" extract "$ubuntu_iso" "$TEST_DIR/ubuntu" || error "Failed to extract Ubuntu ISO"
    
    # Check for expected Ubuntu files
    local expected_files=(
        "isolinux/isolinux.cfg"
        "boot/grub/grub.cfg"
        "casper/vmlinuz"
    )
    
    local found=0
    for file in "${expected_files[@]}"; do
        if [ -e "$TEST_DIR/ubuntu/$file" ]; then
            ((found++))
        fi
    done
    
    if [ $found -gt 0 ]; then
        success "Ubuntu ISO extracted successfully ($found expected files found)"
    else
        error "Ubuntu ISO extraction failed - no expected files found"
    fi
}

# Compare with mount-based extraction
compare_with_mount() {
    info "Comparing Python extraction with mount (if available)..."
    
    # Check if we can use mount
    if ! command -v mount >/dev/null 2>&1 || [ "$EUID" -ne 0 ]; then
        info "Mount not available or not root, skipping comparison"
        return
    fi
    
    # Create mount point
    local mount_point="$TEST_DIR/mount"
    mkdir -p "$mount_point"
    
    # Mount ISO
    if mount -o loop,ro "$TEST_DIR/test.iso" "$mount_point" 2>/dev/null; then
        info "Mounted ISO for comparison"
        
        # Compare directory structures
        local python_files=$(find "$TEST_DIR/extracted" -type f | sort | sed "s|$TEST_DIR/extracted/||")
        local mount_files=$(find "$mount_point" -type f | sort | sed "s|$mount_point/||")
        
        if [ "$python_files" = "$mount_files" ]; then
            success "Python extraction matches mount extraction"
        else
            error "Extraction mismatch between Python and mount"
        fi
        
        umount "$mount_point" || true
    else
        info "Could not mount ISO for comparison"
    fi
}

# Test ISO modification
test_iso_modification() {
    info "Testing ISO modification workflow..."
    
    # Extract ISO
    mkdir -p "$TEST_DIR/modify"
    python3 "$SCRIPT_DIR/pyiso.py" extract "$TEST_DIR/test.iso" "$TEST_DIR/modify" || error "Failed to extract for modification"
    
    # Modify content
    echo "Modified content" > "$TEST_DIR/modify/modified.txt"
    echo "Updated test file" > "$TEST_DIR/modify/test/file.txt"
    
    # Create new ISO
    python3 "$SCRIPT_DIR/pyiso.py" create "$TEST_DIR/modify" "$TEST_DIR/modified.iso" "Modified ISO" || error "Failed to create modified ISO"
    
    # Extract and verify
    mkdir -p "$TEST_DIR/verify"
    python3 "$SCRIPT_DIR/pyiso.py" extract "$TEST_DIR/modified.iso" "$TEST_DIR/verify" || error "Failed to extract modified ISO"
    
    if [ -f "$TEST_DIR/verify/modified.txt" ]; then
        local content=$(cat "$TEST_DIR/verify/modified.txt")
        if [ "$content" = "Modified content" ]; then
            success "ISO modification workflow successful"
        else
            error "Modified content not preserved"
        fi
    else
        error "Modified file not found"
    fi
}

# Performance test
test_performance() {
    info "Testing extraction performance..."
    
    # Find largest ISO available
    local test_iso="$TEST_DIR/test.iso"
    if [ -d "$PROJECT_DIR/downloads" ]; then
        local large_iso=$(find "$PROJECT_DIR/downloads" -name "*.iso" -type f | head -1)
        if [ -n "$large_iso" ]; then
            test_iso="$large_iso"
            info "Using $(basename "$test_iso") ($(du -h "$test_iso" | cut -f1))"
        fi
    fi
    
    # Time extraction
    local start_time=$(date +%s)
    mkdir -p "$TEST_DIR/perf"
    python3 "$SCRIPT_DIR/pyiso.py" extract "$test_iso" "$TEST_DIR/perf" >/dev/null 2>&1
    local end_time=$(date +%s)
    
    local duration=$((end_time - start_time))
    success "Extraction completed in ${duration} seconds"
}

# Main test execution
main() {
    info "Python ISO Fallback Test Suite"
    echo
    
    # Check Python availability
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required but not installed"
    fi
    
    # Check pyiso.py exists
    if [ ! -f "$SCRIPT_DIR/pyiso.py" ]; then
        error "pyiso.py not found in $SCRIPT_DIR"
    fi
    
    # Run tests
    create_test_iso
    extract_test_iso
    test_ubuntu_iso
    compare_with_mount
    test_iso_modification
    test_performance
    
    echo
    success "All Python fallback tests completed successfully!"
    info "Python-based ISO manipulation is working correctly"
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
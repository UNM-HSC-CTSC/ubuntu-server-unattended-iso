#!/bin/bash

# Ubuntu Server Unattended ISO Builder - Test Suite
# This script validates the environment and tests all functionality

set -euo pipefail

# Colors for output
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    # Disable colors if NO_COLOR is set or not running in a terminal
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
declare -a FAILED_TESTS=()

# Helper functions
pass() {
    if [ -z "$GREEN" ]; then
        echo "PASS: $1"
    else
        echo -e "${GREEN}✓${NC} $1"
    fi
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    if [ -z "$RED" ]; then
        echo "FAIL: $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
    FAILED_TESTS+=("$1")
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

info() {
    if [ -z "$YELLOW" ]; then
        echo "INFO: $1"
    else
        echo -e "${YELLOW}ℹ${NC} $1"
    fi
}

test_case() {
    if [ -z "$YELLOW" ]; then
        echo -e "\nTesting: $1"
    else
        echo -e "\n${YELLOW}Testing:${NC} $1"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test 1: Required tools
test_required_tools() {
    test_case "Required system tools"
    
    local required_tools=("bash" "wget" "curl" "sed" "awk" "grep" "mount" "umount" "dd" "python3")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if command_exists "$tool"; then
            pass "$tool is installed"
        else
            fail "$tool is NOT installed"
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        info "Install missing tools: sudo apt-get install ${missing_tools[*]}"
    fi
    
    # Check for loop device support (required for ISO mounting)
    if [ -e /dev/loop0 ] || timeout 2 losetup -f >/dev/null 2>&1; then
        pass "Loop device support available"
    else
        fail "Loop device support not available"
        info "This is required for mounting ISOs"
    fi
    
    # Check Python version
    if command_exists "python3"; then
        local python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" 2>/dev/null || echo "0.0")
        # Simple version comparison
        local major=$(echo "$python_version" | cut -d. -f1)
        local minor=$(echo "$python_version" | cut -d. -f2)
        if [ "$major" -gt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 6 ]); then
            pass "Python $python_version is sufficient"
        else
            fail "Python $python_version is too old (need 3.6+)"
        fi
    fi
}

# Test 2: Optional but recommended tools
test_optional_tools() {
    test_case "Optional tools"
    
    local optional_tools=("yq" "jq" "shellcheck")
    
    for tool in "${optional_tools[@]}"; do
        if command_exists "$tool"; then
            pass "$tool is installed"
        else
            info "$tool is not installed (optional)"
        fi
    done
}

# Test 3: Directory structure
test_directory_structure() {
    test_case "Directory structure"
    
    local required_dirs=("bin" "lib" "share" "tests")
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            pass "Directory $dir exists"
        else
            fail "Directory $dir is missing"
        fi
    done
}

# Test 4: Required scripts exist
test_required_scripts() {
    test_case "Required scripts"
    
    local required_scripts=("bin/ubuntu-iso" "bin/ubuntu-iso-generate")
    
    for script in "${required_scripts[@]}"; do
        if [ -f "$script" ]; then
            pass "Script $script exists"
            
            # Check if executable
            if [ -x "$script" ]; then
                pass "Script $script is executable"
            else
                fail "Script $script is NOT executable"
            fi
        else
            fail "Script $script is missing"
        fi
    done
}

# Test 5: Profile validation
test_profile_validation() {
    test_case "Profile structure validation"
    
    if [ -d "profiles" ] && [ "$(ls -A profiles/)" ]; then
        for profile_dir in profiles/*/; do
            if [ -d "$profile_dir" ]; then
                profile_name=$(basename "$profile_dir")
                
                # Check for autoinstall.yaml
                if [ -f "${profile_dir}autoinstall.yaml" ]; then
                    pass "Profile '$profile_name' has autoinstall.yaml"
                    
                    # Validate YAML syntax if yq is available
                    if command_exists "yq"; then
                        if yq eval '.' "${profile_dir}autoinstall.yaml" >/dev/null 2>&1; then
                            pass "Profile '$profile_name' has valid YAML syntax"
                        else
                            fail "Profile '$profile_name' has invalid YAML syntax"
                        fi
                    fi
                else
                    fail "Profile '$profile_name' missing autoinstall.yaml"
                fi
                
                # Check for README.md (optional but recommended)
                if [ -f "${profile_dir}README.md" ]; then
                    pass "Profile '$profile_name' has README.md"
                else
                    info "Profile '$profile_name' missing README.md (optional)"
                fi
            fi
        done
    else
        info "No profiles found to validate"
    fi
}

# Test 6: Environment configuration
test_environment_config() {
    test_case "Environment configuration"
    
    # Check for .env.example
    if [ -f ".env.example" ]; then
        pass ".env.example exists"
    else
        fail ".env.example is missing"
    fi
    
    # Check if .env exists
    if [ -f ".env" ]; then
        pass ".env exists"
        
        # Source and validate required variables
        # shellcheck disable=SC1091
        source .env
        
        if [ -n "${UBUNTU_VERSION:-}" ]; then
            pass "UBUNTU_VERSION is set: $UBUNTU_VERSION"
        else
            fail "UBUNTU_VERSION is not set"
        fi
        
        if [ -n "${UBUNTU_MIRROR:-}" ]; then
            pass "UBUNTU_MIRROR is set: $UBUNTU_MIRROR"
        else
            info "UBUNTU_MIRROR is not set (will use default)"
        fi
    else
        info ".env does not exist (will use defaults)"
    fi
}

# Test 7: GitHub Actions configuration
test_github_actions() {
    test_case "GitHub Actions configuration"
    
    if [ -f ".github/workflows/ci.yml" ]; then
        pass "GitHub Actions workflow exists"
        
        # Basic YAML validation
        if command_exists "yq"; then
            if yq eval '.' .github/workflows/ci.yml >/dev/null 2>&1; then
                pass "GitHub Actions workflow has valid YAML syntax"
            else
                fail "GitHub Actions workflow has invalid YAML syntax"
            fi
        elif command_exists "python3" && python3 -c "import yaml" 2>/dev/null; then
            if python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" 2>/dev/null; then
                pass "GitHub Actions workflow has valid YAML syntax"
            else
                fail "GitHub Actions workflow has invalid YAML syntax"
            fi
        fi
    else
        fail "GitHub Actions workflow is missing"
    fi
}

# Test 8: Git ignore configuration
test_gitignore() {
    test_case "Git ignore configuration"
    
    if [ -f ".gitignore" ]; then
        pass ".gitignore exists"
        
        # Check for important entries
        local required_ignores=("*.iso" "downloads/" "output/")
        for pattern in "${required_ignores[@]}"; do
            if grep -q "^${pattern}$" .gitignore 2>/dev/null; then
                pass ".gitignore includes $pattern"
            else
                fail ".gitignore missing $pattern"
            fi
        done
    else
        fail ".gitignore is missing"
    fi
}

# Test 9: Ubuntu ISO download test
test_iso_download() {
    test_case "Ubuntu ISO download capability"
    
    # Test with a small file first
    local test_url="https://releases.ubuntu.com/22.04/SHA256SUMS"
    
    if curl -s --head "$test_url" | head -n 1 | grep -q "200"; then
        pass "Can reach Ubuntu release server"
    else
        fail "Cannot reach Ubuntu release server"
    fi
}

# Test 10: ISO tools abstraction
test_iso_tools() {
    test_case "ISO tools abstraction layer"
    
    if [ -f "lib/iso-tools.sh" ]; then
        pass "lib/iso-tools.sh exists"
        
        # Source and test functions
        if bash -c "source lib/iso-tools.sh && type detect_iso_backend >/dev/null 2>&1"; then
            pass "iso-tools.sh can be sourced"
            
            # Test backend detection
            local backend=$(bash -c "source lib/iso-tools.sh && detect_iso_backend && echo \$ISO_BACKEND")
            if [ -n "$backend" ]; then
                pass "ISO backend detected: $backend"
            else
                fail "No ISO backend could be detected"
            fi
        else
            fail "iso-tools.sh has syntax errors"
        fi
    else
        fail "lib/iso-tools.sh is missing"
    fi
}

# Test 11: Build script functionality (dry run)
test_build_script() {
    test_case "Build script basic functionality"
    
    if [ -f "bin/ubuntu-iso" ]; then
        # Test help/usage
        if bash bin/ubuntu-iso --help >/dev/null 2>&1; then
            pass "bin/ubuntu-iso --help works"
        else
            info "bin/ubuntu-iso --help not implemented"
        fi
        
        # Test with missing profile (should fail gracefully)
        if bash bin/ubuntu-iso --profile nonexistent 2>&1 | grep -q -E "(not found|does not exist|missing)"; then
            pass "bin/ubuntu-iso handles missing profiles correctly"
        else
            info "bin/ubuntu-iso profile validation needs improvement"
        fi
    else
        info "bin/ubuntu-iso not yet created"
    fi
}

# Test 12: Share directory content
test_share_content() {
    test_case "Share directory content"
    
    # Check for ubuntu-base
    if [ -d "share/ubuntu-base" ]; then
        pass "share/ubuntu-base exists"
        
        if [ -f "share/ubuntu-base/autoinstall.yaml" ]; then
            pass "ubuntu-base autoinstall.yaml exists"
        else
            fail "ubuntu-base autoinstall.yaml missing"
        fi
    else
        fail "share/ubuntu-base directory missing"
    fi
    
    # Check for examples
    if [ -d "share/examples" ]; then
        pass "share/examples exists"
    else
        info "share/examples not created yet"
    fi
}

# Test 13: Library availability
test_library_files() {
    test_case "Library file availability"
    
    local lib_files=("common.sh" "download.sh" "validate.sh" "iso-tools.sh" "pyiso.py")
    for lib in "${lib_files[@]}"; do
        if [ -f "lib/$lib" ]; then
            pass "Library $lib exists"
        else
            fail "Library $lib missing"
        fi
    done
}

# Test 14: Test scripts
test_test_scripts() {
    test_case "Test script availability"
    
    # Check main test script
    if [ -f "test.sh" ]; then
        pass "Main test.sh exists"
    else
        fail "Main test.sh missing"
    fi
    
    # Check for verify-no-credentials script in tests/
    if [ -f "tests/verify-no-credentials.sh" ]; then
        pass "verify-no-credentials.sh exists in tests/"
    else
        info "verify-no-credentials.sh not in tests/ yet"
    fi
}

# Main test execution
main() {
    echo "Ubuntu Server Unattended ISO Builder - Test Suite"
    echo "================================================="
    echo "Running comprehensive tests..."
    
    # Run all tests
    test_required_tools
    test_optional_tools
    test_directory_structure
    test_required_scripts
    test_profile_validation
    test_environment_config
    test_github_actions
    test_gitignore
    test_iso_download
    test_iso_tools
    test_build_script
    test_share_content
    test_library_files
    test_test_scripts
    
    # Summary
    echo -e "\n================================================="
    echo "Test Summary:"
    echo "  Tests run:    $TESTS_RUN"
    if [ -z "$GREEN" ]; then
        echo "  Tests passed: $TESTS_PASSED"
        echo "  Tests failed: $TESTS_FAILED"
    else
        echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
        echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
    fi
    
    if [ $TESTS_FAILED -gt 0 ]; then
        if [ -z "$RED" ]; then
            echo -e "\nFailed tests:"
            for failed in "${FAILED_TESTS[@]}"; do
                echo "  - $failed"
            done
            echo -e "\nTest suite FAILED"
        else
            echo -e "\n${RED}Failed tests:${NC}"
            for failed in "${FAILED_TESTS[@]}"; do
                echo "  - $failed"
            done
            echo -e "\n${RED}✗ Test suite FAILED${NC}"
        fi
        exit 1
    else
        if [ -z "$GREEN" ]; then
            echo -e "\nAll tests PASSED"
        else
            echo -e "\n${GREEN}✓ All tests PASSED${NC}"
        fi
        exit 0
    fi
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main
fi
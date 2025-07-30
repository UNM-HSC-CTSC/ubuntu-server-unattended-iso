#!/bin/bash

# Test suite for credential injection functionality
# Tests environment variable validation, password complexity, and cleanup

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Test counters
TESTS=0
PASSES=0
FAILURES=0

# Colors
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Test output functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSES=$((PASSES + 1))
    TESTS=$((TESTS + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILURES=$((FAILURES + 1))
    TESTS=$((TESTS + 1))
}

info() {
    echo -e "${YELLOW}→${NC} $1"
}

test_case() {
    echo -e "\nTesting: $1"
}

# Test 1: Template profile exists
test_template_profile_exists() {
    test_case "Template-secure profile existence"
    
    if [ -d "$PROJECT_DIR/profiles/template-secure" ]; then
        pass "template-secure profile directory exists"
        
        if [ -f "$PROJECT_DIR/profiles/template-secure/autoinstall.yaml" ]; then
            pass "template-secure autoinstall.yaml exists"
            
            # Check for required placeholders
            local placeholders=("{{DEFAULT_USERNAME}}" "{{DEFAULT_USER_PASSWORD_HASH}}" "{{DEFAULT_USER_SSH_KEY}}" "{{ROOT_PASSWORD_HASH}}")
            local missing=0
            
            for placeholder in "${placeholders[@]}"; do
                if grep -q "$placeholder" "$PROJECT_DIR/profiles/template-secure/autoinstall.yaml"; then
                    pass "Found placeholder: $placeholder"
                else
                    fail "Missing placeholder: $placeholder"
                    missing=$((missing + 1))
                fi
            done
            
            if [ $missing -eq 0 ]; then
                pass "All required placeholders present"
            fi
        else
            fail "template-secure autoinstall.yaml missing"
        fi
    else
        fail "template-secure profile directory missing"
    fi
}

# Test 2: Environment variable validation
test_environment_variables_required() {
    test_case "Environment variable requirements"
    
    # Save current environment
    local saved_username="${DEFAULT_USERNAME:-}"
    local saved_password="${DEFAULT_USER_PASSWORD:-}"
    local saved_ssh="${DEFAULT_USER_SSH_KEY:-}"
    local saved_root="${ROOT_PASSWORD:-}"
    
    # Test missing DEFAULT_USERNAME
    unset DEFAULT_USERNAME DEFAULT_USER_PASSWORD DEFAULT_USER_SSH_KEY ROOT_PASSWORD
    local output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "DEFAULT_USERNAME environment variable is required"; then
        pass "Missing DEFAULT_USERNAME detected"
    else
        fail "Missing DEFAULT_USERNAME not detected"
    fi
    
    # Test missing DEFAULT_USER_PASSWORD
    export DEFAULT_USERNAME="testuser"
    unset DEFAULT_USER_PASSWORD DEFAULT_USER_SSH_KEY ROOT_PASSWORD
    output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "DEFAULT_USER_PASSWORD environment variable is required"; then
        pass "Missing DEFAULT_USER_PASSWORD detected"
    else
        fail "Missing DEFAULT_USER_PASSWORD not detected"
    fi
    
    # Test missing DEFAULT_USER_SSH_KEY
    export DEFAULT_USERNAME="testuser"
    export DEFAULT_USER_PASSWORD="Test@Pass123!"
    unset DEFAULT_USER_SSH_KEY ROOT_PASSWORD
    output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "DEFAULT_USER_SSH_KEY environment variable is required"; then
        pass "Missing DEFAULT_USER_SSH_KEY detected"
    else
        fail "Missing DEFAULT_USER_SSH_KEY not detected"
    fi
    
    # Test missing ROOT_PASSWORD
    export DEFAULT_USERNAME="testuser"
    export DEFAULT_USER_PASSWORD="Test@Pass123!"
    export DEFAULT_USER_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest test@example"
    unset ROOT_PASSWORD
    output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "ROOT_PASSWORD environment variable is required"; then
        pass "Missing ROOT_PASSWORD detected"
    else
        fail "Missing ROOT_PASSWORD not detected"
    fi
    
    # Restore environment
    [ -n "$saved_username" ] && export DEFAULT_USERNAME="$saved_username"
    [ -n "$saved_password" ] && export DEFAULT_USER_PASSWORD="$saved_password"
    [ -n "$saved_ssh" ] && export DEFAULT_USER_SSH_KEY="$saved_ssh"
    [ -n "$saved_root" ] && export ROOT_PASSWORD="$saved_root"
}

# Test 3: Username validation
test_username_validation() {
    test_case "Username format validation"
    
    # Set other required vars
    export DEFAULT_USER_PASSWORD="Test@Pass123!"
    export DEFAULT_USER_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest test@example"
    export ROOT_PASSWORD="Root@Pass123!"
    
    # Test invalid username (starts with number)
    export DEFAULT_USERNAME="123user"
    local output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "Invalid username format"; then
        pass "Invalid username rejected (starts with number)"
    else
        fail "Invalid username accepted (starts with number)"
    fi
    
    # Test valid username
    export DEFAULT_USERNAME="testuser"
    # For valid username, we need to check it gets past username validation
    # It will fail later at ISO download, but that's OK
    output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if ! echo "$output" | grep -q "Invalid username format"; then
        pass "Valid username accepted"
    else
        fail "Valid username rejected"
    fi
}

# Test 4: Password validation
test_password_validation() {
    test_case "Password complexity requirements"
    
    # Set other required vars
    export DEFAULT_USERNAME="testuser"
    export DEFAULT_USER_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest test@example"
    export ROOT_PASSWORD="ComplexP@ss123!"
    
    # Test too short password
    export DEFAULT_USER_PASSWORD="short1!"
    local output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "at least 12 characters"; then
        pass "Short password rejected"
    else
        fail "Short password accepted"
    fi
    
    # Test no uppercase
    export DEFAULT_USER_PASSWORD="alllowercase123!"
    output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "uppercase letter"; then
        pass "No uppercase password rejected"
    else
        fail "No uppercase password accepted"
    fi
    
    # Test blank password
    export DEFAULT_USER_PASSWORD="   "
    output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "cannot be blank"; then
        pass "Blank password rejected"
    else
        fail "Blank password accepted"
    fi
}

# Test 5: SSH key validation
test_ssh_key_validation() {
    test_case "SSH key format validation"
    
    # Set other required vars
    export DEFAULT_USERNAME="testuser"
    export DEFAULT_USER_PASSWORD="Test@Pass123!"
    export ROOT_PASSWORD="Root@Pass123!"
    
    # Test invalid SSH key
    export DEFAULT_USER_SSH_KEY="invalid-key-format"
    local output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if echo "$output" | grep -q "Invalid SSH key format"; then
        pass "Invalid SSH key rejected"
    else
        fail "Invalid SSH key accepted"
    fi
    
    # Test valid SSH key
    export DEFAULT_USER_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICgdohPufSmzDCyv23zozo/T5k+54rVS0lP6Yx3Kaf/G test@example"
    output=$("$PROJECT_DIR/build-iso.sh" --profile template-secure 2>&1 || true)
    if ! echo "$output" | grep -q "Invalid SSH key format"; then
        pass "Valid SSH key accepted"
    else
        fail "Valid SSH key rejected"
    fi
}

# Test 6: Secure cleanup verification
test_secure_cleanup() {
    test_case "Secure cleanup after build"
    
    # This would require actually running a build, so we'll check the script has cleanup
    if grep -q "secure_cleanup" "$PROJECT_DIR/build-iso.sh"; then
        pass "secure_cleanup function exists"
    else
        fail "secure_cleanup function missing"
    fi
    
    if grep -q "shred.*-n 3" "$PROJECT_DIR/build-iso.sh"; then
        pass "Uses secure shred for file deletion"
    else
        fail "Does not use secure shred"
    fi
    
    if grep -q "unset.*PASSWORD" "$PROJECT_DIR/build-iso.sh"; then
        pass "Clears password environment variables"
    else
        fail "Does not clear password environment variables"
    fi
}

# Test 7: Template processing
test_template_processing() {
    test_case "Template placeholder substitution"
    
    # Check that build-iso.sh has template processing for template-secure
    if grep -q "sed.*{{DEFAULT_USERNAME}}" "$PROJECT_DIR/build-iso.sh"; then
        pass "Processes DEFAULT_USERNAME placeholder"
    else
        fail "Missing DEFAULT_USERNAME processing"
    fi
    
    if grep -q "sed.*{{DEFAULT_USER_PASSWORD_HASH}}" "$PROJECT_DIR/build-iso.sh"; then
        pass "Processes DEFAULT_USER_PASSWORD_HASH placeholder"
    else
        fail "Missing DEFAULT_USER_PASSWORD_HASH processing"
    fi
    
    if grep -q "sed.*{{DEFAULT_USER_SSH_KEY}}" "$PROJECT_DIR/build-iso.sh"; then
        pass "Processes DEFAULT_USER_SSH_KEY placeholder"
    else
        fail "Missing DEFAULT_USER_SSH_KEY processing"
    fi
    
    if grep -q "sed.*{{ROOT_PASSWORD_HASH}}" "$PROJECT_DIR/build-iso.sh"; then
        pass "Processes ROOT_PASSWORD_HASH placeholder"
    else
        fail "Missing ROOT_PASSWORD_HASH processing"
    fi
}

# Main test runner
main() {
    echo "Credential Injection Test Suite"
    echo "==============================="
    
    # Run all tests
    test_template_profile_exists
    test_environment_variables_required
    test_username_validation
    test_password_validation
    test_ssh_key_validation
    test_secure_cleanup
    test_template_processing
    
    # Summary
    echo
    echo "Test Summary"
    echo "============"
    echo "Total tests: $TESTS"
    echo -e "${GREEN}Passed: $PASSES${NC}"
    echo -e "${RED}Failed: $FAILURES${NC}"
    
    # Exit with failure if any tests failed
    if [ $FAILURES -gt 0 ]; then
        exit 1
    else
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
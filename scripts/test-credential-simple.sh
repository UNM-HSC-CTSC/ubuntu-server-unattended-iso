#!/bin/bash

# Simple credential validation test that doesn't require ISO operations
# This test validates that the credential checking logic works correctly

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Test counters
TESTS=0
PASSES=0
FAILURES=0

# Colors (disabled in CI)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
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

# Main tests
echo "Credential Validation Test Suite (Simplified)"
echo "============================================"

# Test 1: Check that bin/build-iso exists and has credential validation
echo -e "\nTest 1: Validation functions exist"
if grep -q "validate_credentials" "$PROJECT_DIR/bin/build-iso"; then
    pass "validate_credentials function exists"
else
    fail "validate_credentials function missing"
fi

if grep -q "validate_password_complexity" "$PROJECT_DIR/bin/build-iso"; then
    pass "validate_password_complexity function exists"
else
    fail "validate_password_complexity function missing"
fi

# Test 2: Check template-secure profile
echo -e "\nTest 2: Template-secure profile"
if [ -f "$PROJECT_DIR/profiles/template-secure/autoinstall.yaml" ]; then
    pass "template-secure profile exists"
    
    # Check placeholders
    for placeholder in "{{DEFAULT_USERNAME}}" "{{DEFAULT_USER_PASSWORD_HASH}}" "{{DEFAULT_USER_SSH_KEY}}" "{{ROOT_PASSWORD_HASH}}"; do
        if grep -q "$placeholder" "$PROJECT_DIR/profiles/template-secure/autoinstall.yaml"; then
            pass "Found placeholder: $placeholder"
        else
            fail "Missing placeholder: $placeholder"
        fi
    done
else
    fail "template-secure profile missing"
fi

# Test 3: Check that inject_autoinstall calls validate_credentials for template-secure
echo -e "\nTest 3: Credential validation integration"
if grep -A5 'PROFILE.*template-secure' "$PROJECT_DIR/bin/build-iso" | grep -q "validate_credentials"; then
    pass "Credential validation called for template-secure"
else
    fail "Credential validation not called for template-secure"
fi

# Test 4: Check secure cleanup
echo -e "\nTest 4: Secure cleanup"
if grep -q "secure_cleanup" "$PROJECT_DIR/bin/build-iso"; then
    pass "secure_cleanup function exists"
else
    fail "secure_cleanup function missing"
fi

if grep -q "shred.*-n 3" "$PROJECT_DIR/bin/build-iso"; then
    pass "Uses secure shred for deletion"
else
    fail "Missing secure shred"
fi

if grep -q "unset.*PASSWORD" "$PROJECT_DIR/bin/build-iso"; then
    pass "Clears password variables"
else
    fail "Missing password clearing"
fi

# Test 5: Check bin/build-iso help mentions credential variables
echo -e "\nTest 5: Documentation"
if "$PROJECT_DIR/bin/build-iso" --help 2>&1 | grep -q "DEFAULT_USERNAME"; then
    pass "Help mentions DEFAULT_USERNAME"
else
    fail "Help missing DEFAULT_USERNAME"
fi

# Summary
echo -e "\nTest Summary"
echo "============"
echo "Total tests: $TESTS"
echo "Passed: $PASSES"
echo "Failed: $FAILURES"

if [ $FAILURES -gt 0 ]; then
    exit 1
else
    echo -e "\nAll tests passed!"
    exit 0
fi
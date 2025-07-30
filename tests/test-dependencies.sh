#!/bin/bash

# Test that all required dependencies are available
# This ensures consistency across local, Docker, and GitHub Actions environments

set -euo pipefail

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

FAILED=0

echo "Ubuntu ISO Builder - Dependency Check"
echo "===================================="
echo

# Test Python version
echo "Checking Python..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
    echo -e "${GREEN}✓${NC} Python $PYTHON_VERSION found"
else
    echo -e "${RED}✗${NC} Python 3 not found"
    FAILED=1
fi

# Test Python dependencies
echo -e "\nChecking Python modules..."
if python3 -c "import yaml" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} PyYAML available"
else
    echo -e "${RED}✗${NC} PyYAML missing (install: pip3 install pyyaml or apt install python3-yaml)"
    FAILED=1
fi

# Test system tools
echo -e "\nChecking required system tools..."
REQUIRED_TOOLS=(
    "bash:GNU Bash"
    "wget:Download tool"
    "curl:Download tool"
    "sed:Text processing"
    "awk:Text processing"
    "grep:Text searching"
    "mount:ISO mounting"
    "umount:ISO unmounting"
    "dd:Disk operations"
)

for tool_desc in "${REQUIRED_TOOLS[@]}"; do
    IFS=':' read -r tool desc <<< "$tool_desc"
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $tool - $desc"
    else
        echo -e "${RED}✗${NC} $tool - $desc (REQUIRED)"
        FAILED=1
    fi
done

# Test optional ISO creation tools
echo -e "\nChecking optional ISO tools..."
ISO_TOOLS_FOUND=0

if command -v genisoimage >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} genisoimage - ISO creation tool"
    ISO_TOOLS_FOUND=1
else
    echo -e "${YELLOW}○${NC} genisoimage - Not found"
fi

if command -v mkisofs >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} mkisofs - ISO creation tool"
    ISO_TOOLS_FOUND=1
else
    echo -e "${YELLOW}○${NC} mkisofs - Not found"
fi

if command -v xorriso >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} xorriso - ISO creation tool"
    ISO_TOOLS_FOUND=1
else
    echo -e "${YELLOW}○${NC} xorriso - Not found"
fi

if [ $ISO_TOOLS_FOUND -eq 0 ]; then
    echo -e "${YELLOW}⚠${NC}  No ISO creation tools found. Python fallback will be used."
fi

# Test optional tools
echo -e "\nChecking optional tools..."
OPTIONAL_TOOLS=(
    "make:Build automation"
    "gh:GitHub CLI"
    "git:Version control"
)

for tool_desc in "${OPTIONAL_TOOLS[@]}"; do
    IFS=':' read -r tool desc <<< "$tool_desc"
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $tool - $desc"
    else
        echo -e "${YELLOW}○${NC} $tool - $desc (optional)"
    fi
done

# Test file permissions
echo -e "\nChecking script permissions..."
SCRIPTS=(
    "bin/ubuntu-iso"
    "bin/ubuntu-iso-generate"
    "bin/ubuntu-iso-check-updates"
)

for script in "${SCRIPTS[@]}"; do
    if [ -x "$script" ]; then
        echo -e "${GREEN}✓${NC} $script is executable"
    else
        echo -e "${RED}✗${NC} $script is not executable"
        FAILED=1
    fi
done

# Summary
echo
echo "===================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All required dependencies are satisfied${NC}"
    exit 0
else
    echo -e "${RED}✗ Some required dependencies are missing${NC}"
    echo -e "${YELLOW}Run 'make install' to install dependencies${NC}"
    exit 1
fi
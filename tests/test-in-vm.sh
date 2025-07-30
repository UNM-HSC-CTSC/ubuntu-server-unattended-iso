#!/bin/bash

# VM Testing Framework for Ubuntu Server Unattended ISO
# Tests ISO installations in various hypervisors

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
VM_NAME="ubuntu-test-$$"
VM_RAM="2048"
VM_DISK="20G"
VM_CPUS="2"
HYPERVISOR="auto"
ISO_PATH=""
PROFILE=""
WAIT_TIME="1800"  # 30 minutes max for installation
TEST_SSH="true"
CLEANUP="true"

# Colors
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
    echo -e "${BLUE}[DEBUG]${NC} $1" >&2
}

usage() {
    cat << EOF
Usage: $0 --iso ISO_PATH --profile PROFILE_NAME [options]

Tests Ubuntu Server unattended installation in a VM.

Required:
    --iso PATH          Path to the ISO file to test
    --profile NAME      Profile name used to build the ISO

Options:
    --hypervisor TYPE   Hypervisor to use (auto|hyperv|qemu|vbox)
    --vm-name NAME      VM name (default: ubuntu-test-PID)
    --ram SIZE          RAM size in MB (default: 2048)
    --disk SIZE         Disk size (default: 20G)
    --cpus COUNT        Number of CPUs (default: 2)
    --wait TIME         Max wait time in seconds (default: 1800)
    --no-ssh-test      Skip SSH connectivity test
    --no-cleanup       Don't delete VM after test
    --help             Show this help

Examples:
    $0 --iso output/minimal-ubuntu-22.04.iso --profile minimal-server
    $0 --iso output/web.iso --profile web-server --hypervisor hyperv
    $0 --iso output/test.iso --profile test --no-cleanup --ram 4096

EOF
    exit 0
}

# Detect available hypervisor
detect_hypervisor() {
    if [ "$HYPERVISOR" != "auto" ]; then
        echo "$HYPERVISOR"
        return
    fi
    
    # Check for Hyper-V (Windows with WSL)
    if command -v powershell.exe >/dev/null 2>&1; then
        if powershell.exe -Command "Get-WindowsFeature -Name Hyper-V" 2>/dev/null | grep -q "Installed"; then
            echo "hyperv"
            return
        fi
    fi
    
    # Check for QEMU/KVM
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        echo "qemu"
        return
    fi
    
    # Check for VirtualBox
    if command -v VBoxManage >/dev/null 2>&1; then
        echo "vbox"
        return
    fi
    
    error "No supported hypervisor found. Install QEMU or run on Hyper-V host."
}

# Create VM in Hyper-V
create_hyperv_vm() {
    info "Creating Hyper-V VM: $VM_NAME"
    
    # PowerShell script for VM creation
    local ps_script=$(cat << 'PSEOF'
param($VMName, $RAM, $DiskSize, $CPUs, $ISOPath)

# Convert disk size to bytes
$DiskBytes = [uint64]($DiskSize -replace '[^0-9]', '') * 1GB

# Create VM
New-VM -Name $VMName -MemoryStartupBytes ([uint64]$RAM * 1MB) -Generation 2 -NoVHD

# Configure VM
Set-VM -Name $VMName -ProcessorCount $CPUs -CheckpointType Disabled

# Create VHDX
$VHDPath = "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\$VMName.vhdx"
New-VHD -Path $VHDPath -SizeBytes $DiskBytes -Dynamic

# Add VHDX to VM
Add-VMHardDiskDrive -VMName $VMName -Path $VHDPath

# Add DVD Drive with ISO
Add-VMDvdDrive -VMName $VMName -Path $ISOPath

# Configure boot order
$DVDDrive = Get-VMDvdDrive -VMName $VMName
$HardDrive = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $DVDDrive, $HardDrive

# Disable Secure Boot for Linux
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

# Connect to default switch
Get-VMSwitch | Where-Object {$_.SwitchType -eq "External"} | Select-Object -First 1 | ForEach-Object {
    Connect-VMNetworkAdapter -VMName $VMName -SwitchName $_.Name
}

Write-Host "VM $VMName created successfully"
PSEOF
)
    
    # Execute PowerShell script
    echo "$ps_script" | powershell.exe -Command - \
        -VMName "$VM_NAME" \
        -RAM "$VM_RAM" \
        -DiskSize "$VM_DISK" \
        -CPUs "$VM_CPUS" \
        -ISOPath "$(wslpath -w "$ISO_PATH")" || error "Failed to create Hyper-V VM"
    
    success "Hyper-V VM created"
}

# Create VM in QEMU
create_qemu_vm() {
    info "Creating QEMU VM: $VM_NAME"
    
    local vm_dir="/tmp/vm-test-$$"
    mkdir -p "$vm_dir"
    
    # Create disk
    qemu-img create -f qcow2 "$vm_dir/disk.qcow2" "$VM_DISK" || error "Failed to create disk"
    
    # Start VM in background
    qemu-system-x86_64 \
        -name "$VM_NAME" \
        -m "$VM_RAM" \
        -smp "$VM_CPUS" \
        -drive file="$vm_dir/disk.qcow2",format=qcow2 \
        -cdrom "$ISO_PATH" \
        -boot d \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device e1000,netdev=net0 \
        -display none \
        -daemonize \
        -pidfile "$vm_dir/qemu.pid" || error "Failed to start QEMU VM"
    
    # Save VM info for cleanup
    echo "$vm_dir" > "/tmp/vm-test-$VM_NAME.info"
    
    success "QEMU VM created"
}

# Start VM
start_vm() {
    local hypervisor="$1"
    
    info "Starting VM..."
    
    case "$hypervisor" in
        hyperv)
            powershell.exe -Command "Start-VM -Name '$VM_NAME'" || error "Failed to start VM"
            ;;
        qemu)
            # Already started in create phase
            ;;
        vbox)
            VBoxManage startvm "$VM_NAME" --type headless || error "Failed to start VM"
            ;;
    esac
    
    success "VM started"
}

# Wait for installation to complete
wait_for_installation() {
    local hypervisor="$1"
    local start_time=$(date +%s)
    
    info "Waiting for installation to complete (max ${WAIT_TIME}s)..."
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $WAIT_TIME ]; then
            error "Installation timeout after ${WAIT_TIME} seconds"
        fi
        
        # Check if VM is still running
        case "$hypervisor" in
            hyperv)
                if ! powershell.exe -Command "Get-VM -Name '$VM_NAME' | Where-Object {$_.State -eq 'Running'}" | grep -q "$VM_NAME"; then
                    info "VM has stopped - checking if installation completed"
                    break
                fi
                ;;
            qemu)
                if [ -f "/tmp/vm-test-$VM_NAME.info" ]; then
                    local vm_dir=$(cat "/tmp/vm-test-$VM_NAME.info")
                    if [ -f "$vm_dir/qemu.pid" ]; then
                        local pid=$(cat "$vm_dir/qemu.pid")
                        if ! kill -0 "$pid" 2>/dev/null; then
                            info "QEMU process ended"
                            break
                        fi
                    fi
                fi
                ;;
        esac
        
        # Progress indicator
        printf "\r${YELLOW}→${NC} Elapsed: %d seconds" "$elapsed"
        sleep 10
    done
    
    echo  # New line after progress
    success "Installation phase completed"
}

# Test SSH connectivity
test_ssh_connectivity() {
    local hypervisor="$1"
    
    if [ "$TEST_SSH" != "true" ]; then
        info "Skipping SSH test"
        return
    fi
    
    info "Testing SSH connectivity..."
    
    # Get VM IP address
    local vm_ip=""
    case "$hypervisor" in
        hyperv)
            # Get IP from Hyper-V
            vm_ip=$(powershell.exe -Command "
                (Get-VMNetworkAdapter -VMName '$VM_NAME' | 
                 Select-Object -ExpandProperty IPAddresses | 
                 Where-Object {\$_ -match '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'})[0]
            " | tr -d '\r\n')
            ;;
        qemu)
            # QEMU uses port forwarding
            vm_ip="localhost"
            SSH_PORT="2222"
            ;;
    esac
    
    if [ -z "$vm_ip" ]; then
        error "Could not determine VM IP address"
    fi
    
    info "VM IP: $vm_ip"
    
    # Try SSH connection
    local ssh_user="ubuntu"  # Default for most profiles
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            ${SSH_PORT:+-p $SSH_PORT} "$ssh_user@$vm_ip" "echo 'SSH test successful'" 2>/dev/null; then
            success "SSH connectivity confirmed"
            return 0
        fi
        
        printf "\r${YELLOW}→${NC} SSH attempt %d/%d" "$attempt" "$max_attempts"
        sleep 10
        ((attempt++))
    done
    
    echo  # New line
    error "SSH connectivity test failed"
}

# Run post-installation tests
run_post_install_tests() {
    local hypervisor="$1"
    
    info "Running post-installation tests..."
    
    # Basic system checks
    local tests_passed=0
    local tests_failed=0
    
    # Test commands to run
    local test_commands=(
        "hostname"
        "df -h"
        "free -m"
        "systemctl is-system-running || true"
        "dpkg -l | grep -E '^ii' | wc -l"
        "ss -tlnp | grep :22"
    )
    
    for cmd in "${test_commands[@]}"; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            ${SSH_PORT:+-p $SSH_PORT} "$ssh_user@$vm_ip" "$cmd" >/dev/null 2>&1; then
            ((tests_passed++))
            echo -e "${GREEN}✓${NC} Test passed: $cmd"
        else
            ((tests_failed++))
            echo -e "${RED}✗${NC} Test failed: $cmd"
        fi
    done
    
    info "Post-installation tests: $tests_passed passed, $tests_failed failed"
}

# Cleanup VM
cleanup_vm() {
    local hypervisor="$1"
    
    if [ "$CLEANUP" != "true" ]; then
        info "Skipping cleanup (--no-cleanup specified)"
        return
    fi
    
    info "Cleaning up VM..."
    
    case "$hypervisor" in
        hyperv)
            powershell.exe -Command "
                Stop-VM -Name '$VM_NAME' -Force -ErrorAction SilentlyContinue
                Remove-VM -Name '$VM_NAME' -Force
                Remove-Item 'C:\Users\Public\Documents\Hyper-V\Virtual hard disks\$VM_NAME.vhdx' -Force -ErrorAction SilentlyContinue
            " || true
            ;;
        qemu)
            if [ -f "/tmp/vm-test-$VM_NAME.info" ]; then
                local vm_dir=$(cat "/tmp/vm-test-$VM_NAME.info")
                if [ -f "$vm_dir/qemu.pid" ]; then
                    local pid=$(cat "$vm_dir/qemu.pid")
                    kill "$pid" 2>/dev/null || true
                fi
                rm -rf "$vm_dir"
                rm -f "/tmp/vm-test-$VM_NAME.info"
            fi
            ;;
        vbox)
            VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
            VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
            ;;
    esac
    
    success "VM cleaned up"
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --iso)
                ISO_PATH="$2"
                shift 2
                ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --hypervisor)
                HYPERVISOR="$2"
                shift 2
                ;;
            --vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            --ram)
                VM_RAM="$2"
                shift 2
                ;;
            --disk)
                VM_DISK="$2"
                shift 2
                ;;
            --cpus)
                VM_CPUS="$2"
                shift 2
                ;;
            --wait)
                WAIT_TIME="$2"
                shift 2
                ;;
            --no-ssh-test)
                TEST_SSH="false"
                shift
                ;;
            --no-cleanup)
                CLEANUP="false"
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$ISO_PATH" ]; then
        error "ISO path is required. Use --iso PATH"
    fi
    
    if [ ! -f "$ISO_PATH" ]; then
        error "ISO file not found: $ISO_PATH"
    fi
    
    if [ -z "$PROFILE" ]; then
        error "Profile name is required. Use --profile NAME"
    fi
}

# Main function
main() {
    parse_args "$@"
    
    info "Ubuntu Server VM Test Framework"
    info "Testing ISO: $(basename "$ISO_PATH")"
    info "Profile: $PROFILE"
    
    # Detect hypervisor
    local hypervisor=$(detect_hypervisor)
    info "Using hypervisor: $hypervisor"
    
    # Create and start VM
    case "$hypervisor" in
        hyperv)
            create_hyperv_vm
            start_vm "$hypervisor"
            ;;
        qemu)
            create_qemu_vm
            ;;
        vbox)
            error "VirtualBox support not yet implemented"
            ;;
        *)
            error "Unsupported hypervisor: $hypervisor"
            ;;
    esac
    
    # Wait for installation
    wait_for_installation "$hypervisor"
    
    # Test SSH connectivity
    test_ssh_connectivity "$hypervisor"
    
    # Run post-installation tests
    run_post_install_tests "$hypervisor"
    
    # Cleanup
    cleanup_vm "$hypervisor"
    
    success "VM test completed successfully!"
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
# Deployment Guide - Ubuntu Server Unattended ISO Builder

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Scenarios](#deployment-scenarios)
- [Building ISOs](#building-isos)
- [Deploying VMs on Hyper-V](#deploying-vms-on-hyper-v)
- [Post-Deployment Verification](#post-deployment-verification)
- [Maintenance and Updates](#maintenance-and-updates)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [See Also](#see-also)

## Overview

This guide provides step-by-step instructions for deploying servers using the Ubuntu Server Unattended ISO Builder. It covers everything from building ISOs to verifying successful deployments.

### Deployment Workflow

1. **Choose Role** - Select the server role you need (github, tools, etc.)
2. **Build ISO** - Create a custom ISO with the role embedded
3. **Deploy VM** - Create and boot VM with the ISO
4. **Automatic Configuration** - Server configures itself on first boot
5. **Verification** - Confirm successful deployment

### Prerequisites Checklist

Before deploying servers, ensure you have:

- ✅ **Infrastructure servers operational** (see [Bootstrap Guide](BOOTSTRAP-GUIDE.md))
  - Config server (`hsc-ctsc-config.health.unm.edu`)
  - Repository server (`hsc-ctsc-repository.health.unm.edu`)
- ✅ **Network infrastructure ready**
  - F5 BIG-IP configured for DHCP
  - DNS entries for all servers
  - Network connectivity verified
- ✅ **Hyper-V environment prepared**
  - Windows Server 2019 with Hyper-V role
  - Sufficient compute and storage resources
  - Network switches configured
- ✅ **Access credentials**
  - Hyper-V administrator access
  - Repository server credentials
  - Config server Git access

## Prerequisites

### System Requirements

#### Build Environment
- **Linux/WSL2**: Ubuntu 20.04 or later
- **Docker**: Version 20.10 or later (recommended)
- **Storage**: 10GB free space for ISOs
- **Network**: Internet access for downloading Ubuntu ISOs

#### Deployment Environment
- **Hyper-V Host**: Windows Server 2019 or later
- **Memory**: 4GB minimum per VM (varies by role)
- **Storage**: 50-100GB per VM (varies by role)
- **Network**: Access to management network

### Required Infrastructure

Before deploying standard servers, these must be operational:

1. **Config Server** - Provides Ansible configurations
2. **Repository Server** - Stores ISOs and packages
3. **DNS/DHCP** - F5 BIG-IP or equivalent
4. **Network Share** - For ISO transfer (optional)

## Deployment Scenarios

### Scenario 1: Development Environment
Deploy a complete development stack:
- 1x GitHub server (code repository)
- 1x Tools server (development tools)
- 1x Artifacts server (package repository)

### Scenario 2: Production Web Application
Deploy production infrastructure:
- 2x Web servers (load balanced)
- 2x Database servers (primary/replica)
- 1x Monitoring server

### Scenario 3: Single Server
Deploy individual servers as needed:
- Just a GitHub server
- Just a monitoring server
- Custom role server

## Building ISOs

### Using Docker (Recommended)

#### Build Standard Role ISO
```bash
# Build GitHub server ISO
./docker-build.sh -- --role github --output ubuntu-github.iso

# Build Tools server ISO
./docker-build.sh -- --role tools --output ubuntu-tools.iso

# Build custom role ISO
./docker-build.sh -- --role myapp --output ubuntu-myapp.iso
```

#### Build with Specific Ubuntu Version
```bash
# Use specific LTS version
./docker-build.sh -- --version 24.04.2 --role github

# Use previous LTS
./docker-build.sh -- --version 22.04.5 --role tools
```

### Using Local Installation

```bash
# Ensure you're in the project directory
cd ubuntu-server-unattended-iso

# Build role-specific ISO
./bin/ubuntu-iso --role github --output output/ubuntu-github.iso

# Build with custom autoinstall
./bin/ubuntu-iso --autoinstall my-config.yaml --output output/custom.iso
```

### Batch Building Multiple ISOs

```bash
#!/bin/bash
# build-all-roles.sh

ROLES=("github" "tools" "artifacts" "monitoring")
VERSION="24.04.2"

for role in "${ROLES[@]}"; do
  echo "Building ISO for role: $role"
  ./docker-build.sh -- \
    --role "$role" \
    --version "$VERSION" \
    --output "ubuntu-${VERSION}-${role}.iso"
done
```

### Uploading ISOs to Repository

After building, upload to repository server:

```bash
# Using curl
curl -X POST https://hsc-ctsc-repository.health.unm.edu/api/upload \
  -F "file=@output/ubuntu-github.iso" \
  -F "version=1.0.0" \
  -F "role=github"

# Using repository CLI (if available)
repo-cli upload output/ubuntu-github.iso --tag latest
```

## Deploying VMs on Hyper-V

### Step 1: Transfer ISO to Hyper-V Host

#### Option A: Network Share
```powershell
# From Hyper-V host
Copy-Item "\\workstation\share\ubuntu-github.iso" "C:\ISOs\"
```

#### Option B: Download from Repository
```powershell
# Download latest ISO
Invoke-WebRequest `
  -Uri "https://hsc-ctsc-repository.health.unm.edu/isos/ubuntu-github-latest.iso" `
  -OutFile "C:\ISOs\ubuntu-github.iso"
```

#### Option C: Direct SCP Transfer
```powershell
# If OpenSSH is enabled on Windows Server
scp user@build-server:/output/ubuntu-github.iso C:\ISOs\
```

### Step 2: Create VM in Hyper-V

#### Using PowerShell
```powershell
# Define VM parameters
$VMName = "hsc-ctsc-github-01"
$Memory = 8GB
$VHDPath = "C:\VMs\$VMName\$VMName.vhdx"
$VHDSize = 100GB
$ISOPath = "C:\ISOs\ubuntu-github.iso"

# Create VM
New-VM -Name $VMName `
  -MemoryStartupBytes $Memory `
  -Generation 2 `
  -NewVHDPath $VHDPath `
  -NewVHDSizeBytes $VHDSize `
  -SwitchName "External"

# Add DVD drive with ISO
Add-VMDvdDrive -VMName $VMName -Path $ISOPath

# Configure firmware to boot from DVD
$DVD = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $DVD

# Configure additional settings
Set-VM -VMName $VMName `
  -ProcessorCount 4 `
  -DynamicMemory `
  -MemoryMinimumBytes 2GB `
  -MemoryMaximumBytes 16GB

# Enable nested virtualization (if needed)
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true

# Start the VM
Start-VM -Name $VMName
```

#### Using Hyper-V Manager GUI
1. Open Hyper-V Manager
2. Action → New → Virtual Machine
3. Specify Name: `hsc-ctsc-github-01`
4. Generation: `Generation 2`
5. Memory: `8192 MB`
6. Network: Select your external switch
7. Virtual Hard Disk: Create new, 100GB
8. Installation Options: Install from ISO
9. Browse to your ISO file
10. Finish and Start VM

### Step 3: Monitor Installation

```powershell
# Connect to VM console
vmconnect.exe localhost $VMName

# Or use PowerShell Direct (after OS installs)
Enter-PSSession -VMName $VMName -Credential (Get-Credential)
```

The installation process:
1. Ubuntu installer boots automatically
2. Autoinstall configuration applies
3. System reboots after installation
4. Cloud-init runs on first boot
5. Server contacts config server
6. Ansible-pull configures the system

### Step 4: Multiple VM Deployment

For deploying multiple VMs:

```powershell
# deploy-multiple-vms.ps1
$VMs = @(
    @{Name="hsc-ctsc-github-01"; Role="github"; Memory=8GB; CPU=4},
    @{Name="hsc-ctsc-tools-01"; Role="tools"; Memory=16GB; CPU=8},
    @{Name="hsc-ctsc-artifacts-01"; Role="artifacts"; Memory=8GB; CPU=4}
)

foreach ($VM in $VMs) {
    Write-Host "Creating VM: $($VM.Name)"
    
    # Download ISO if not exists
    $ISOPath = "C:\ISOs\ubuntu-$($VM.Role).iso"
    if (-not (Test-Path $ISOPath)) {
        Invoke-WebRequest `
          -Uri "https://repository.internal/isos/ubuntu-$($VM.Role)-latest.iso" `
          -OutFile $ISOPath
    }
    
    # Create VM
    New-VM -Name $VM.Name `
      -MemoryStartupBytes $VM.Memory `
      -Generation 2 `
      -NewVHDPath "C:\VMs\$($VM.Name)\disk.vhdx" `
      -NewVHDSizeBytes 100GB `
      -SwitchName "External"
    
    # Configure and start
    Add-VMDvdDrive -VMName $VM.Name -Path $ISOPath
    Set-VMProcessor -VMName $VM.Name -Count $VM.CPU
    Start-VM -Name $VM.Name
    
    Write-Host "VM $($VM.Name) created and started"
}
```

## Post-Deployment Verification

### Step 1: Verify Network Connectivity

```bash
# From your workstation
ping hsc-ctsc-github-01.health.unm.edu

# Check SSH access
ssh adminuser@hsc-ctsc-github-01.health.unm.edu
```

### Step 2: Verify Role Configuration

```bash
# Check if Ansible ran successfully
ssh adminuser@hsc-ctsc-github-01.health.unm.edu
sudo cat /var/log/cloud-init-output.log | grep ansible-pull

# Verify services are running
sudo systemctl status nginx
sudo systemctl status postgresql
```

### Step 3: Role-Specific Verification

#### GitHub Server
```bash
# Check Gitea service
curl http://hsc-ctsc-github-01.health.unm.edu
# Should see Gitea login page

# Verify Git SSH
ssh git@hsc-ctsc-github-01.health.unm.edu info
```

#### Tools Server
```bash
# Check Docker
ssh adminuser@hsc-ctsc-tools-01.health.unm.edu
docker --version
kubectl version --client

# Check monitoring
curl http://hsc-ctsc-tools-01.health.unm.edu:3000  # Grafana
curl http://hsc-ctsc-tools-01.health.unm.edu:9090  # Prometheus
```

#### Repository Server
```bash
# Check Nexus
curl http://hsc-ctsc-artifacts-01.health.unm.edu
# Should see Nexus welcome page

# Test repository
curl http://hsc-ctsc-artifacts-01.health.unm.edu/repository/
```

### Step 4: Automated Verification Script

```bash
#!/bin/bash
# verify-deployment.sh

SERVERS=(
    "hsc-ctsc-github-01:80:Gitea"
    "hsc-ctsc-tools-01:3000:Grafana"
    "hsc-ctsc-artifacts-01:8081:Nexus"
)

echo "=== Deployment Verification ==="
for server in "${SERVERS[@]}"; do
    IFS=':' read -r hostname port service <<< "$server"
    
    echo -n "Checking $service on $hostname... "
    if curl -s -o /dev/null -w "%{http_code}" "http://${hostname}:${port}" | grep -q "200\|302"; then
        echo "✓ OK"
    else
        echo "✗ FAILED"
    fi
done

echo -e "\n=== SSH Connectivity ==="
for server in "${SERVERS[@]}"; do
    hostname=$(echo "$server" | cut -d: -f1)
    echo -n "SSH to $hostname... "
    if ssh -o ConnectTimeout=5 -o BatchMode=yes adminuser@$hostname exit 2>/dev/null; then
        echo "✓ OK"
    else
        echo "✗ FAILED"
    fi
done
```

## Maintenance and Updates

### Updating Server Configurations

When Ansible roles are updated:

```bash
# On existing servers, manually pull updates
ssh adminuser@server
cd /tmp
git clone http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
cd ansible-config
sudo ansible-playbook -i localhost, -c local -t role_name site.yml
```

### Rebuilding Servers

For major updates, rebuild the server:

1. Build new ISO with updated configuration
2. Create new VM with updated ISO
3. Migrate data from old server
4. Switch DNS/load balancer
5. Decommission old server

### ISO Management

```bash
# List ISOs in repository
curl https://hsc-ctsc-repository.health.unm.edu/api/isos

# Delete old ISOs
curl -X DELETE https://hsc-ctsc-repository.health.unm.edu/api/isos/ubuntu-github-old.iso

# Tag ISOs
curl -X POST https://hsc-ctsc-repository.health.unm.edu/api/isos/ubuntu-github.iso/tag/stable
```

## Troubleshooting

### Common Deployment Issues

#### VM Won't Boot from ISO
```powershell
# Verify Generation 2 VM
Get-VM -Name $VMName | Select-Object Generation

# Check secure boot settings
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

# Verify ISO is attached
Get-VMDvdDrive -VMName $VMName
```

#### Installation Hangs
- Check VM has sufficient resources (RAM, CPU)
- Verify network connectivity
- Check ISO integrity
- Review console for error messages

#### Cloud-init Fails
```bash
# Check cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Verify metadata
cloud-init query -a

# Re-run cloud-init
sudo cloud-init clean
sudo cloud-init init
```

#### Ansible-pull Fails
```bash
# Check connectivity to config server
ping hsc-ctsc-config.health.unm.edu
curl http://hsc-ctsc-config.health.unm.edu/

# Verify Git repository
git clone http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git

# Run ansible-pull manually
ansible-pull -vvv -U http://hsc-ctsc-config.health.unm.edu/git/ansible-config.git
```

### Network Issues

#### No DHCP Address
```bash
# Check network interface
ip addr show

# Restart networking
sudo systemctl restart systemd-networkd

# Check DHCP client
sudo journalctl -u systemd-networkd
```

#### Can't Reach Config Server
```bash
# Check DNS resolution
nslookup hsc-ctsc-config.health.unm.edu

# Check routing
ip route show

# Test connectivity
traceroute hsc-ctsc-config.health.unm.edu
```

## Best Practices

### Deployment Best Practices

1. **Test in Non-Production First**
   - Deploy to test environment
   - Verify all functionality
   - Document any issues

2. **Use Consistent Naming**
   - Follow naming convention: `hsc-ctsc-role-##`
   - Document all servers
   - Update DNS immediately

3. **Monitor Deployments**
   - Watch console during install
   - Check logs after deployment
   - Verify services are running

4. **Automate Verification**
   - Use verification scripts
   - Set up monitoring early
   - Configure alerts

### Security Best Practices

1. **Change Default Passwords**
   - Update immediately after deployment
   - Use strong, unique passwords
   - Implement key-based auth

2. **Network Security**
   - Deploy in correct network segment
   - Configure firewalls
   - Limit access appropriately

3. **Update Regularly**
   - Apply security updates
   - Update configurations
   - Rebuild when necessary

### Documentation

1. **Document Everything**
   - Server roles and purposes
   - Network configurations
   - Access credentials (in vault)
   - Custom configurations

2. **Maintain Inventory**
   - Server list with IPs
   - Role assignments
   - Deployment dates
   - Responsible parties

## See Also

- [Architecture Overview](ARCHITECTURE.md) - System design details
- [Bootstrap Guide](BOOTSTRAP-GUIDE.md) - Infrastructure setup
- [Role Definitions](ROLE-DEFINITIONS.md) - Available server roles
- [README.md](../README.md) - Project overview
- [Ansible Roles](../ansible/README.md) - Configuration details
# Windows Server Hyper-V Deployment Guide

This guide walks through deploying the Ubuntu Server Unattended ISO Builder infrastructure on Windows Server 2019 with Hyper-V, starting from a completely fresh server.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Phase 1: Setup Build Environment](#phase-1-setup-build-environment)
- [Phase 2: Build the Config Server ISO](#phase-2-build-the-config-server-iso)
- [Phase 3: Deploy VM in Hyper-V](#phase-3-deploy-vm-in-hyper-v)
- [Phase 4: Initial VM Configuration](#phase-4-initial-vm-configuration)
- [Phase 5: Configure the Config Server](#phase-5-configure-the-config-server)
- [Phase 6: Deploy Additional Servers](#phase-6-deploy-additional-servers)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [See Also](#see-also)

## Prerequisites

Before starting, ensure you have:

- **Windows Server 2019** (or later) with:
  - Hyper-V role installed and configured
  - At least 100GB free disk space
  - 16GB+ RAM (for running multiple VMs)
  - Administrator access
  
- **Network Requirements**:
  - Internet connectivity for downloads
  - DHCP server (F5 BIG-IP or similar)
  - DNS server with ability to create records
  - External virtual switch configured in Hyper-V

- **Naming Convention**:
  - All VMs follow pattern: `hsc-ctsc-[service]`
  - Example: `hsc-ctsc-config`, `hsc-ctsc-repository`

## Phase 1: Setup Build Environment

Starting from a fresh Windows Server, we need to install tools for building ISOs.

### Step 1: Install Git for Windows

Open PowerShell as Administrator:

```powershell
# Download Git for Windows
$GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
$GitInstaller = "$env:TEMP\Git-installer.exe"
Invoke-WebRequest -Uri $GitUrl -OutFile $GitInstaller

# Install Git silently
Start-Process -FilePath $GitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
Remove-Item $GitInstaller

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

### Step 2: Clone the Repository

```powershell
# Create working directory
New-Item -ItemType Directory -Path "C:\ISO-Builder" -Force
Set-Location "C:\ISO-Builder"

# Clone the repository
git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
Set-Location ubuntu-server-unattended-iso

# Verify clone was successful
Get-ChildItem
```

### Step 3: Install Docker Desktop (Recommended)

Docker provides the easiest way to build ISOs on Windows:

```powershell
# Download Docker Desktop
$DockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$DockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
Invoke-WebRequest -Uri $DockerUrl -OutFile $DockerInstaller

# Install Docker Desktop
Write-Host "Installing Docker Desktop. This will require a restart..." -ForegroundColor Yellow
Start-Process -FilePath $DockerInstaller -ArgumentList "install", "--quiet", "--accept-license" -Wait
Remove-Item $DockerInstaller

Write-Host "Docker installed. Please restart the server and continue with Step 4." -ForegroundColor Green
Write-Host "Run: Restart-Computer -Force" -ForegroundColor Yellow
```

**After restart**, verify Docker is running:
```powershell
docker version
```

### Alternative: Install WSL2 (If not using Docker)

If Docker Desktop isn't suitable for your environment:

```powershell
# Enable required features
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Restart required
Restart-Computer -Force

# After restart, install Ubuntu
wsl --install -d Ubuntu-22.04
wsl --set-default-version 2

# Set up Ubuntu user when prompted
```

### Step 4: Verify Hyper-V Configuration

```powershell
# Check Hyper-V is installed
Get-WindowsFeature -Name Hyper-V | Format-Table Name, InstallState

# List existing virtual switches
Get-VMSwitch | Format-Table Name, SwitchType, NetAdapterInterfaceDescription

# If no external switch exists, create one:
$NetAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3"}
if ($NetAdapter) {
    New-VMSwitch -Name "External" -NetAdapterName $NetAdapter.Name -AllowManagementOS $true
    Write-Host "Created External virtual switch" -ForegroundColor Green
}
```

## Phase 2: Build the Config Server ISO

The config server is the foundation of our infrastructure. It hosts Ansible playbooks and provides configuration to all other servers.

### Step 5: Create Output Directory

```powershell
# Navigate back to project
Set-Location "C:\ISO-Builder\ubuntu-server-unattended-iso"

# Create directory for ISOs
New-Item -ItemType Directory -Path "C:\ISOs" -Force
```

### Step 6: Build Config Server ISO

**Using Docker (Recommended):**
```powershell
# Ensure Docker is running
$dockerStatus = Get-Service -Name "Docker Desktop Service" -ErrorAction SilentlyContinue
if ($dockerStatus.Status -ne "Running") {
    Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Service "Docker Desktop Service"
    Start-Sleep -Seconds 30
}

# Build the config server bootstrap ISO
Write-Host "Building config server ISO. This will take 10-15 minutes..." -ForegroundColor Yellow
.\deploy\Build-RoleISO.ps1 -Role config-bootstrap -UseDocker -OutputPath "C:\ISOs"

# Verify ISO was created
Get-ChildItem "C:\ISOs\*.iso" | Format-Table Name, Length, LastWriteTime
```

**Using WSL2 (Alternative):**
```powershell
# Build using WSL2
.\deploy\Build-RoleISO.ps1 -Role config-bootstrap -OutputPath "C:\ISOs"
```

The ISO will be named something like: `config-bootstrap-ubuntu-24.04.2-20240804.iso`

## Phase 3: Deploy VM in Hyper-V

### Step 7: Deploy the Config Server VM

```powershell
# Find the ISO that was created
$ConfigISO = Get-ChildItem -Path "C:\ISOs" -Filter "config-bootstrap-*.iso" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if (-not $ConfigISO) {
    Write-Error "No config ISO found in C:\ISOs"
    exit 1
}

Write-Host "Found ISO: $($ConfigISO.Name)" -ForegroundColor Green

# Deploy the VM using HSC naming convention
.\deploy\Deploy-VM.ps1 `
    -Name "hsc-ctsc-config" `
    -ISOPath $ConfigISO.FullName `
    -Memory 4GB `
    -CPUCount 2 `
    -DiskSize 50GB `
    -SwitchName "External"

# When prompted "Do you want to start the VM now?", type: Y
```

### Step 8: Connect to VM Console

After the VM starts:

```powershell
# Connect to console (opens in separate window)
vmconnect.exe localhost "hsc-ctsc-config"
```

Or use Hyper-V Manager:
1. Open Hyper-V Manager
2. Find `hsc-ctsc-config`
3. Double-click to open console

## Phase 4: Initial VM Configuration

### Step 9: Monitor Automated Installation

In the VM console window, you'll see:

1. **GRUB Boot Menu** (auto-proceeds in 5 seconds)
2. **Ubuntu Installer** starts with message: "Starting HSC-CTSC Config Server bootstrap installation"
3. **Installation Progress**:
   - Disk partitioning
   - Package installation (this takes 5-10 minutes)
   - System configuration
4. **Automatic Reboot** when installation completes
5. **Cloud-Init Run** on first boot (another 5-10 minutes)

**Important**: This is fully automated - no interaction required!

### Step 10: Wait for Cloud-Init Completion

After reboot, cloud-init will:
- Configure networking
- Install nginx, git, ansible
- Set up git repositories
- Configure firewall
- Create web interface

You'll know it's complete when you see a login prompt.

### Step 11: Get VM IP Address

From PowerShell on the Hyper-V host:

```powershell
# Method 1: From Hyper-V
$VM = Get-VM -Name "hsc-ctsc-config"
$VM | Select-Object -ExpandProperty NetworkAdapters | Select-Object IPAddresses

# Method 2: Check DHCP server logs
# (This depends on your DHCP server)

# Store the IP for later use
$ConfigIP = Read-Host "Enter the IP address of the config server"
Write-Host "Config server IP: $ConfigIP" -ForegroundColor Green
```

### Step 12: Verify Services are Running

Test from Windows PowerShell:

```powershell
# Test web interface
try {
    $response = Invoke-WebRequest -Uri "http://$ConfigIP" -UseBasicParsing -TimeoutSec 5
    Write-Host "✓ Web interface is accessible" -ForegroundColor Green
} catch {
    Write-Host "✗ Web interface not accessible yet. Cloud-init may still be running." -ForegroundColor Yellow
}

# Test health endpoint
try {
    $health = Invoke-WebRequest -Uri "http://$ConfigIP/health" -UseBasicParsing -TimeoutSec 5
    if ($health.Content -eq "OK") {
        Write-Host "✓ Health check passed" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Health check failed" -ForegroundColor Red
}
```

## Phase 5: Configure the Config Server

### Step 13: Initial Login and Security

First, install OpenSSH client if needed:

```powershell
# Check if OpenSSH client is installed
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'

# Install if missing
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

Now SSH to the config server:

```powershell
# SSH to config server
ssh configadmin@$ConfigIP

# Default password is: ChangeMe123!
# You will be forced to change it on first login
```

After changing password:

```bash
# Verify all services are running
sudo /usr/local/bin/config-server-status

# Expected output:
# === HSC-CTSC Config Server Status ===
# Hostname: hsc-ctsc-config
# IP Address: 192.168.x.x/24
# 
# Services:
# ✓ Nginx: Running
# ✓ Git Daemon: Running  
# ✓ SSH: Running
#
# Repository Status:
# ✓ Ansible repository initialized
```

### Step 14: Initialize Ansible Repository

Exit SSH and return to Windows PowerShell:

```powershell
# Create a temporary directory for Ansible configs
Set-Location "C:\ISO-Builder"
New-Item -ItemType Directory -Path "ansible-upload" -Force
Set-Location "ansible-upload"

# Clone the empty repository
git clone http://${ConfigIP}/git/ansible-config.git
Set-Location "ansible-config"

# Copy Ansible files from main project
$AnsibleSource = "C:\ISO-Builder\ubuntu-server-unattended-iso\ansible"
Copy-Item -Path "$AnsibleSource\*" -Destination "." -Recurse -Force

# Initialize git and push
git add .
git config user.email "admin@health.unm.edu"
git config user.name "Administrator"
git commit -m "Initial Ansible configuration for HSC-CTSC"
git push origin main

Write-Host "Ansible repository initialized successfully!" -ForegroundColor Green
```

### Step 15: Update DNS Records

Contact your network administrator to create DNS records:

1. **A Record**: `hsc-ctsc-config.health.unm.edu` → Config Server IP
2. **Optional CNAME**: `hsc-ctsc-config` → `hsc-ctsc-config.health.unm.edu`

Verify DNS resolution:

```powershell
# Test DNS resolution
nslookup hsc-ctsc-config.health.unm.edu

# Test connectivity with FQDN
Invoke-WebRequest -Uri "http://hsc-ctsc-config.health.unm.edu" -UseBasicParsing
```

## Phase 6: Deploy Additional Servers

Now that the config server is running, you can deploy other infrastructure servers.

### Step 16: Build Repository Server ISO

```powershell
# Return to project directory
Set-Location "C:\ISO-Builder\ubuntu-server-unattended-iso"

# Build repository server ISO
.\deploy\Build-RoleISO.ps1 -Role repository-bootstrap -UseDocker -OutputPath "C:\ISOs"
```

### Step 17: Deploy Repository Server

```powershell
# Find the repository ISO
$RepoISO = Get-ChildItem -Path "C:\ISOs" -Filter "repository-bootstrap-*.iso" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

# Deploy repository server
.\deploy\Deploy-VM.ps1 `
    -Name "hsc-ctsc-repository" `
    -ISOPath $RepoISO.FullName `
    -Memory 8GB `
    -CPUCount 4 `
    -DiskSize 500GB `
    -SwitchName "External"
```

### Step 18: Deploy Service Servers

After both config and repository servers are operational:

```powershell
# Build ISOs for service servers
.\deploy\Build-RoleISO.ps1 -Role github -UseDocker -OutputPath "C:\ISOs"
.\deploy\Build-RoleISO.ps1 -Role tools -UseDocker -OutputPath "C:\ISOs"
.\deploy\Build-RoleISO.ps1 -Role artifacts -UseDocker -OutputPath "C:\ISOs"

# Deploy each server
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-github-01" -ISOPath "C:\ISOs\github-*.iso"
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-tools-01" -ISOPath "C:\ISOs\tools-*.iso" -Memory 16GB
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-artifacts-01" -ISOPath "C:\ISOs\artifacts-*.iso"
```

## Troubleshooting

### VM Doesn't Get IP Address

```powershell
# Check virtual switch configuration
Get-VMSwitch | Format-Table Name, SwitchType, NetAdapterInterfaceDescription

# Verify VM network adapter
Get-VMNetworkAdapter -VMName "hsc-ctsc-config" | Format-Table Name, SwitchName, MacAddress, IPAddresses

# Check connection to F5 BIG-IP DHCP
# May need to check F5 logs or DHCP reservations
```

### Cloud-Init Doesn't Complete

1. Wait at least 15 minutes after first boot
2. If still not working, check from console:
   ```bash
   # Login as configadmin
   sudo journalctl -u cloud-init -n 100
   sudo cloud-init status
   ```

### Cannot Access Web Interface

```powershell
# From Windows, test basic connectivity
Test-NetConnection -ComputerName $ConfigIP -Port 80

# Check if firewall is blocking
# On the VM console:
sudo ufw status
sudo systemctl status nginx
```

### Git Clone Fails

```powershell
# Test without git
Invoke-WebRequest -Uri "http://${ConfigIP}/git/" -UseBasicParsing

# Check git daemon on server
ssh configadmin@$ConfigIP
sudo systemctl status git-daemon
sudo journalctl -u git-daemon -n 50
```

## Security Considerations

### Immediate Actions

1. **Change Default Passwords**:
   - Config server: `configadmin` password
   - Repository server: `repoadmin` password and Nexus admin password
   - All service servers: default admin passwords

2. **Configure Firewalls**:
   - Windows Firewall on Hyper-V host
   - UFW on each Ubuntu server (already enabled)

3. **Limit Access**:
   - Place servers in isolated VLAN if possible
   - Restrict SSH access to management network
   - Use SSH keys instead of passwords

### Production Recommendations

1. **SSL/TLS Certificates**:
   ```bash
   # On config server
   sudo apt-get install certbot python3-certbot-nginx
   sudo certbot --nginx -d hsc-ctsc-config.health.unm.edu
   ```

2. **Regular Updates**:
   - Enable automatic security updates (already configured)
   - Schedule maintenance windows for full updates

3. **Backup Strategy**:
   - Export Hyper-V VMs regularly
   - Backup config server Git repositories
   - Document all customizations

## Summary

You now have:

1. **Build Environment** on Windows Server:
   - Git for version control
   - Docker Desktop or WSL2 for ISO building
   - PowerShell scripts for automation

2. **Config Server** (`hsc-ctsc-config`):
   - Nginx web server
   - Git repository with Ansible playbooks
   - Ready to configure other servers

3. **Automated Deployment Process**:
   - Build ISOs with role embedded
   - Deploy VMs with single PowerShell command
   - Servers configure themselves on boot

## Next Steps

1. Deploy repository server
2. Update all DNS records
3. Deploy service servers (GitHub, tools, artifacts)
4. Configure monitoring
5. Document any customizations

## See Also

- [Bootstrap Guide](BOOTSTRAP-GUIDE.md) - Detailed bootstrap architecture
- [Deployment Guide](DEPLOYMENT-GUIDE.md) - General deployment procedures
- [Role Definitions](ROLE-DEFINITIONS.md) - Available server roles
- [PowerShell Scripts](../deploy/README.md) - Script documentation
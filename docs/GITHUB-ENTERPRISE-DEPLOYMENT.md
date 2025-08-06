# GitHub Enterprise Server Deployment on Hyper-V

This guide provides comprehensive instructions for deploying GitHub Enterprise Server on Hyper-V and integrating it with self-hosted GitHub Actions runners.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Phase 1: Deploy GitHub Enterprise Server](#phase-1-deploy-github-enterprise-server)
- [Phase 2: Initial Configuration](#phase-2-initial-configuration)
- [Phase 3: Deploy GitHub Runners](#phase-3-deploy-github-runners)
- [Phase 4: Integration](#phase-4-integration)
- [Management](#management)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [See Also](#see-also)

## Overview

GitHub Enterprise Server is a self-hosted version of GitHub that runs on your infrastructure. This guide covers deploying it on Hyper-V alongside self-hosted runners to create a complete GitHub infrastructure solution.

### Key Points
- GitHub Enterprise Server is a **closed virtual appliance**
- You **cannot install additional software** on it
- Runners must be deployed on **separate VMs**
- Both can run on the **same Hyper-V host**

## Prerequisites

### Licensing
- Valid GitHub Enterprise Server license
- Contact GitHub Sales for licensing: https://enterprise.github.com

### Hardware Requirements

**For GitHub Enterprise Server VM:**
- CPU: 8 vCPUs minimum (16+ recommended)
- RAM: 32GB minimum (64GB+ recommended)
- Storage: 200GB minimum (500GB+ recommended SSD)
- Network: 1 Gbps adapter

**For Runner VMs (per VM):**
- CPU: 4 vCPUs minimum
- RAM: 8GB minimum
- Storage: 100GB
- Network: 1 Gbps adapter

**Hyper-V Host Total:**
- CPU: 16+ cores recommended
- RAM: 96GB+ recommended
- Storage: 1TB+ SSD recommended

### Software Requirements
- Windows Server 2019 or later with Hyper-V role
- PowerShell 5.1 or later
- Internet connectivity for downloads

### Network Requirements
- Static IP addresses available
- DNS entries can be created
- Firewall rules can be configured
- Internal vSwitch for VM communication

## Architecture

```
Hyper-V Host
│
├── External vSwitch (Internet access)
│   └── Connected to physical NIC
│
├── Internal vSwitch (VM communication)
│   └── 10.10.10.0/24 subnet
│
├── GitHub Enterprise Server VM
│   ├── Name: hsc-ctsc-github-enterprise
│   ├── IP: DHCP from F5 + 10.10.10.10
│   ├── Resources: 16 vCPU, 64GB RAM, 500GB disk
│   └── Provides: Git, Web UI, API, Actions orchestration
│
└── GitHub Runners VM(s)
    ├── Name: hsc-ctsc-github-runners-01
    ├── IP: DHCP from F5 + 10.10.10.11
    ├── Resources: 8 vCPU, 16GB RAM, 200GB disk
    └── Runs: 4 ephemeral runners
```

## Phase 1: Deploy GitHub Enterprise Server

### Step 1: Download GitHub Enterprise Server

1. **Get your license**:
   ```powershell
   # Visit: https://enterprise.github.com/download
   # Log in with your GitHub account
   # Download your license file (ghl_*.ghl)
   ```

2. **Download the Hyper-V image**:
   ```powershell
   # Create download directory
   New-Item -Path "C:\GitHub-Enterprise" -ItemType Directory -Force
   cd C:\GitHub-Enterprise
   
   # Download will require authentication
   # Get the URL from the download portal
   # Example (URL will be unique to your license):
   $downloadUrl = "https://github-enterprise.s3.amazonaws.com/hyperv/github-enterprise-hyperv-3.11.0.vhd"
   
   # Download (this is a large file, ~15GB)
   Invoke-WebRequest -Uri $downloadUrl -OutFile "github-enterprise.vhd" -UseBasicParsing
   ```

### Step 2: Create Virtual Machine

```powershell
# Variables
$VMName = "hsc-ctsc-github-enterprise"
$VHDPath = "C:\GitHub-Enterprise\github-enterprise.vhd"
$VMPath = "C:\VMs\GitHub-Enterprise"
$Memory = 64GB
$ProcessorCount = 16

# Create VM directory
New-Item -Path $VMPath -ItemType Directory -Force

# Copy VHD to VM directory (GitHub provides fixed VHD)
$NewVHDPath = "$VMPath\$VMName.vhd"
Copy-Item -Path $VHDPath -Destination $NewVHDPath

# Create the VM
New-VM -Name $VMName `
  -MemoryStartupBytes $Memory `
  -VHDPath $NewVHDPath `
  -Generation 1 `
  -SwitchName "External"

# Configure VM
Set-VMProcessor -VMName $VMName -Count $ProcessorCount
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false

# Add data disk for user data (required by GitHub Enterprise)
$DataDisk = "$VMPath\$VMName-data.vhdx"
New-VHD -Path $DataDisk -SizeBytes 400GB -Dynamic
Add-VMHardDiskDrive -VMName $VMName -Path $DataDisk

# Configure networking
Add-VMNetworkAdapter -VMName $VMName -SwitchName "Internal"

# Enable nested virtualization (required for Actions)
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true

# Set automatic start
Set-VM -VMName $VMName -AutomaticStartAction Start -AutomaticStopAction ShutDown

# Start the VM
Start-VM -VMName $VMName

Write-Host "GitHub Enterprise VM created and started" -ForegroundColor Green
Write-Host "Connect via: vmconnect.exe localhost '$VMName'" -ForegroundColor Yellow
```

### Step 3: Initial Network Configuration

1. **Connect to console**:
   ```powershell
   vmconnect.exe localhost "hsc-ctsc-github-enterprise"
   ```

2. **At the blue setup screen**:
   - Press 'S' to get to shell
   - Configure initial networking:
   ```bash
   # View network interfaces
   ip addr show
   
   # Configure primary interface (example)
   # This will be replaced by setup UI
   sudo ifconfig eth0 <IP_FROM_DHCP> netmask 255.255.255.0
   sudo route add default gw <GATEWAY_IP>
   echo "nameserver <DNS_SERVER>" | sudo tee /etc/resolv.conf
   ```

3. **Access web setup**:
   - Open browser to: `http://<IP_ADDRESS>`
   - You'll see the GitHub Enterprise setup page

## Phase 2: Initial Configuration

### Step 1: Upload License

1. Access the setup URL in your browser
2. Click "Upload a license"
3. Upload your `.ghl` license file
4. Set admin password when prompted

### Step 2: Configure Instance

1. **Management Console Password**:
   - Set a strong password
   - This is different from admin user password

2. **Instance Configuration**:
   ```
   Hostname: hsc-ctsc-github-enterprise.health.unm.edu
   ```

3. **Admin User**:
   ```
   Username: ghe-admin
   Email: admin@health.unm.edu
   Password: [Strong Password]
   ```

### Step 3: Configure Authentication

1. **Built-in Authentication** (for initial setup):
   - Enable built-in authentication
   - Can integrate with LDAP/SAML later

2. **Create additional admin users** as needed

### Step 4: Enable GitHub Actions

1. Navigate to: **Management Console** → **Settings** → **Actions**
2. Enable GitHub Actions
3. Configure storage location for artifacts
4. Set retention policies

### Step 5: Configure Network Settings

1. **Subdomain Isolation** (recommended):
   - Enable subdomain isolation
   - Prevents XSS attacks

2. **SSL/TLS**:
   - Upload SSL certificate
   - Or use Let's Encrypt

3. **Firewall Rules** - Allow:
   - 22/tcp (SSH)
   - 80/tcp (HTTP)
   - 443/tcp (HTTPS)
   - 122/tcp (Git over SSH)
   - 9418/tcp (Git protocol)

## Phase 3: Deploy GitHub Runners

### Step 1: Build Runner ISO

```powershell
# Use existing ISO builder
cd C:\ISO-Builder\ubuntu-server-unattended-iso

# Build ISO with GitHub runner role
.\docker-build.ps1 -OutputPath "C:\ISOs"

# Or directly:
.\bin\ubuntu-iso --role github --output C:\ISOs\github-runners.iso
```

### Step 2: Deploy Runner VM

```powershell
# Deploy using existing scripts
.\deploy\Deploy-GitHubRunners.ps1 `
  -VMName "hsc-ctsc-github-runners-01" `
  -ISOPath "C:\ISOs\github-runners.iso" `
  -Memory 16GB `
  -CPUCount 8 `
  -DiskSize 200GB `
  -SwitchName "External"

# Add to internal network
Add-VMNetworkAdapter -VMName "hsc-ctsc-github-runners-01" -SwitchName "Internal"
```

### Step 3: Configure Runner VM

After the VM boots and completes cloud-init:

```bash
# SSH to runner VM
ssh sysadmin@hsc-ctsc-github-runners-01

# Update GitHub Enterprise URL
sudo tee /etc/github-runner/enterprise.conf <<EOF
GITHUB_ENTERPRISE_URL=https://hsc-ctsc-github-enterprise.health.unm.edu
GITHUB_ENTERPRISE_API=https://hsc-ctsc-github-enterprise.health.unm.edu/api/v3
EOF
```

## Phase 4: Integration

### Step 1: Register Runners with Enterprise

1. **Get registration token from GitHub Enterprise**:
   ```bash
   # As enterprise admin, navigate to:
   # Settings → Actions → Runners → New self-hosted runner
   # Copy the token
   ```

2. **Register runners**:
   ```powershell
   # Run from Windows host
   .\deploy\Register-RunnersToEnterprise.ps1 `
     -GitHubURL "https://hsc-ctsc-github-enterprise.health.unm.edu" `
     -Token "REGISTRATION_TOKEN"
   ```

   Or manually on runner VM:
   ```bash
   sudo register-runner
   # Follow prompts, use Enterprise URL
   ```

### Step 2: Configure Runner Groups

1. In GitHub Enterprise, navigate to:
   **Settings** → **Actions** → **Runner groups**

2. Create groups:
   - `production` - For production workflows
   - `development` - For dev/test workflows
   - `secure` - For sensitive workflows

3. Assign runners to groups based on labels

### Step 3: Test Integration

1. **Create test repository** in GitHub Enterprise

2. **Create test workflow**:
   ```yaml
   name: Test Runner
   on: [push]
   jobs:
     test:
       runs-on: self-hosted
       steps:
         - uses: actions/checkout@v3
         - run: |
             echo "Running on: $(hostname)"
             echo "Runner user: $(whoami)"
             docker --version
   ```

3. **Verify execution** in Actions tab

## Management

### Daily Operations

**Check Infrastructure Status**:
```powershell
# From Windows host
.\deploy\Get-GitHubInfrastructure.ps1

# Output shows:
# - GitHub Enterprise: Running, Healthy
# - Runner VMs: 1 running, 4 runners online
# - Network: Connected
```

**Start/Stop Everything**:
```powershell
# Start in correct order
.\deploy\Start-GitHubInfrastructure.ps1

# Stop in correct order
.\deploy\Stop-GitHubInfrastructure.ps1
```

### Backup Procedures

**GitHub Enterprise Backup**:
```bash
# SSH to GitHub Enterprise
ssh admin@hsc-ctsc-github-enterprise.health.unm.edu

# Run backup
ghe-backup

# Backups stored in: /data/user/common/backup
```

**Runner Configuration Backup**:
```bash
# On runner VM
sudo backup-runners
```

### Updates

**GitHub Enterprise Updates**:
1. Download update package from GitHub
2. Upload via Management Console
3. Apply update (requires maintenance window)

**Runner Updates**:
```bash
# On runner VM
sudo update-runners check
sudo update-runners update
```

### Monitoring

**GitHub Enterprise**:
- Management Console: `https://github-enterprise:8443`
- Monitor dashboard: `/setup/monitor`
- System logs: `/setup/logs`

**Runners**:
- Prometheus metrics: `http://runner:9100/metrics`
- Runner status: `sudo runner-status`
- Health check: `sudo runner-health-check`

## Troubleshooting

### GitHub Enterprise Issues

**Cannot Access Web Interface**:
```powershell
# Check VM network
Get-VMNetworkAdapter -VMName "hsc-ctsc-github-enterprise"

# Test connectivity from host
Test-NetConnection -ComputerName <IP> -Port 443

# Check VM console for errors
vmconnect.exe localhost "hsc-ctsc-github-enterprise"
```

**High CPU/Memory Usage**:
```bash
# SSH to GitHub Enterprise
ssh admin@github-enterprise

# Check processes
ghe-top

# Check specific services
ghe-status
```

### Runner Issues

**Runners Show Offline**:
```bash
# On runner VM
sudo runner-status
sudo systemctl status github-runner@*

# Check connectivity to Enterprise
curl -k https://hsc-ctsc-github-enterprise.health.unm.edu/api/v3

# Re-register if needed
sudo register-runner
```

**Jobs Not Running**:
1. Check runner groups and labels
2. Verify repository has access to runners
3. Check workflow `runs-on` matches labels

### Network Issues

**VMs Cannot Communicate**:
```powershell
# Verify internal switch
Get-VMSwitch "Internal"

# Check VM adapters
Get-VMNetworkAdapter -VMName * | Where {$_.SwitchName -eq "Internal"}

# Test connectivity between VMs
# From runner: ping 10.10.10.10
```

## Best Practices

### Security

1. **Network Isolation**:
   - Use internal vSwitch for VM communication
   - Restrict external access via firewall
   - Enable subdomain isolation

2. **Access Control**:
   - Use strong passwords
   - Enable 2FA for all users
   - Audit admin actions

3. **Runner Security**:
   - Use ephemeral runners
   - Don't store secrets on runners
   - Rotate registration tokens

### Performance

1. **Resource Allocation**:
   - Don't overcommit CPU/memory
   - Use SSDs for storage
   - Monitor resource usage

2. **Scaling**:
   - Add runner VMs as needed
   - Distribute load across runners
   - Use runner groups effectively

### Maintenance

1. **Regular Updates**:
   - Schedule monthly maintenance windows
   - Test updates in dev environment
   - Keep runners within 30 days of latest

2. **Backups**:
   - Daily automated backups
   - Test restore procedures
   - Store backups off-host

3. **Monitoring**:
   - Set up alerts for critical issues
   - Review logs regularly
   - Track usage trends

## See Also

- [GitHub Infrastructure Guide](GITHUB-INFRASTRUCTURE.md) - Complete infrastructure overview
- [GitHub Runners Guide](GITHUB-RUNNERS.md) - Detailed runner documentation
- [Windows Deployment Guide](WINDOWS-DEPLOYMENT.md) - Hyper-V deployment procedures
- [Official GitHub Enterprise Docs](https://docs.github.com/en/enterprise-server)
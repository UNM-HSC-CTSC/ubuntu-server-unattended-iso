# Complete GitHub Infrastructure Guide

This guide provides a unified view of deploying and managing a complete GitHub infrastructure including GitHub Enterprise Server and self-hosted runners on Hyper-V.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Deployment Workflow](#deployment-workflow)
- [Management Operations](#management-operations)
- [Integration Guide](#integration-guide)
- [Automation Scripts](#automation-scripts)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Reference](#reference)

## Overview

This infrastructure provides a complete GitHub solution for your organization:

- **GitHub Enterprise Server**: Full GitHub platform running on-premises
- **Self-Hosted Runners**: Scalable CI/CD compute infrastructure
- **Unified Management**: Single-pane-of-glass for the entire system
- **Enterprise Integration**: Works with existing infrastructure (F5, DNS, etc.)

### Key Benefits

1. **Data Sovereignty**: All code and CI/CD stays on-premises
2. **Performance**: Low latency between GitHub and runners
3. **Scalability**: Easy to add more runner capacity
4. **Control**: Full control over compute resources
5. **Integration**: Access to internal resources from workflows

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Hyper-V Host                              │
│                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐         │
│  │ GitHub Enterprise   │  │  Runner Pool        │         │
│  │ Server              │  │                     │         │
│  │                     │  │ ┌─────────────────┐ │         │
│  │ - Git Repositories  │  │ │ Runner VM 01    │ │         │
│  │ - Web Interface     │  │ │ - 4 runners     │ │         │
│  │ - API               │  │ │ - Docker        │ │         │
│  │ - Actions Control   │──┼─┤ - Build tools   │ │         │
│  │                     │  │ └─────────────────┘ │         │
│  │ hsc-ctsc-github-    │  │                     │         │
│  │ enterprise          │  │ ┌─────────────────┐ │         │
│  └─────────────────────┘  │ │ Runner VM 02    │ │         │
│                           │ │ - 4 runners     │ │         │
│                           │ │ - Docker        │ │         │
│                           │ │ - Build tools   │ │         │
│                           │ └─────────────────┘ │         │
│                           │                     │         │
│                           │ hsc-ctsc-github-    │         │
│                           │ runners-01,02...    │         │
│                           └─────────────────────┘         │
│                                                             │
│  Network: External vSwitch + Internal vSwitch               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    F5 BIG-IP (DHCP/DNS)
```

### Component Specifications

**GitHub Enterprise Server VM**:
- vCPUs: 16 (minimum)
- Memory: 64GB (minimum)
- Storage: 500GB SSD (system + data)
- Network: Dual-homed (external + internal)

**Runner VMs** (each):
- vCPUs: 8
- Memory: 16GB
- Storage: 200GB
- Runners: 4 per VM
- Network: Dual-homed (external + internal)

## Quick Start

### Prerequisites

1. **Licensing**:
   ```powershell
   # Get GitHub Enterprise license from:
   # https://enterprise.github.com
   ```

2. **System Requirements**:
   - Windows Server 2019+ with Hyper-V
   - 96GB+ RAM total
   - 1TB+ SSD storage
   - External vSwitch configured

3. **Download Components**:
   ```powershell
   # Clone the infrastructure repository
   git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
   cd ubuntu-server-unattended-iso
   ```

### Rapid Deployment

```powershell
# 1. Deploy GitHub Enterprise Server
.\deploy\Deploy-GitHubEnterprise.ps1 `
  -VHDPath "C:\Downloads\github-enterprise.vhd" `
  -CreateInternalSwitch

# 2. Complete web setup (manual step)
# Browse to VM IP and configure

# 3. Deploy Runner VMs
.\deploy\Deploy-GitHubRunners.ps1 `
  -Count 2 `
  -GitHubEnterpriseURL "https://github.company.com"

# 4. Register Runners
.\deploy\Register-RunnersToEnterprise.ps1 `
  -GitHubURL "https://github.company.com" `
  -Token "YOUR_REGISTRATION_TOKEN"

# 5. Verify Infrastructure
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Status
```

## Deployment Workflow

### Phase 1: Planning

1. **Capacity Planning**:
   - Estimate concurrent workflows
   - Calculate runner requirements
   - Size VMs appropriately

2. **Network Design**:
   - External network for internet/user access
   - Internal network for VM communication
   - Firewall rules

3. **DNS Planning**:
   - github.company.com → Enterprise Server
   - runners.company.com → Runner load balancer (optional)

### Phase 2: GitHub Enterprise Deployment

1. **Download VHD**:
   ```powershell
   # From GitHub with your license
   # ~15GB download
   ```

2. **Deploy VM**:
   ```powershell
   .\deploy\Deploy-GitHubEnterprise.ps1 `
     -VHDPath "path\to\github-enterprise.vhd" `
     -Memory 128GB `
     -CPUCount 32 `
     -DataDiskSize 1TB
   ```

3. **Initial Setup**:
   - Browse to: http://VM_IP
   - Upload license
   - Set passwords
   - Configure hostname
   - Enable Actions

4. **SSL Configuration**:
   - Upload certificates
   - Or enable Let's Encrypt

### Phase 3: Runner Deployment

1. **Build Runner ISO**:
   ```powershell
   # Automatic during deployment
   # Or manual:
   .\docker-build.ps1
   ```

2. **Deploy Runner VMs**:
   ```powershell
   # Deploy 3 runner VMs
   .\deploy\Deploy-GitHubRunners.ps1 `
     -Count 3 `
     -Memory 32GB `
     -CPUCount 16
   ```

3. **Wait for Cloud-Init**:
   - VMs auto-configure
   - Install runner software
   - Configure Docker

### Phase 4: Integration

1. **Get Registration Token**:
   - GitHub Enterprise → Settings → Actions → Runners
   - Click "New self-hosted runner"
   - Copy token

2. **Register All Runners**:
   ```powershell
   .\deploy\Register-RunnersToEnterprise.ps1 `
     -GitHubURL "https://github.company.com" `
     -Token "REGISTRATION_TOKEN" `
     -Scope Enterprise
   ```

3. **Verify Registration**:
   - Check GitHub UI
   - Test with workflow

## Management Operations

### Daily Operations

**Check Status**:
```powershell
# Full infrastructure status
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Status

# Health check
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Health
```

**Start/Stop Operations**:
```powershell
# Start everything
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Start -Component All

# Stop runners only
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Stop -Component Runners

# Restart Enterprise
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Restart -Component Enterprise
```

**Connect to VMs**:
```powershell
# Open console connection
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Connect -Component hsc-ctsc-github-enterprise

# SSH to runners
ssh sysadmin@runner-vm-ip
```

### Maintenance Tasks

**Backup Infrastructure**:
```powershell
# Automated backup of all VMs
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Backup
```

**Update Components**:
```powershell
# GitHub Enterprise (via Management Console)
https://github.company.com:8443

# Runners (on each VM)
ssh sysadmin@runner-vm
sudo update-runners
```

**Scale Runners**:
```powershell
# Add more runner VMs
.\deploy\Deploy-GitHubRunners.ps1 `
  -VMNamePrefix "hsc-ctsc-github-runners" `
  -Count 2 `
  -StartingNumber 4  # Creates 04, 05

# Register new runners
.\deploy\Register-RunnersToEnterprise.ps1
```

### Monitoring

**GitHub Enterprise**:
- Management Console: https://github:8443/setup/monitor
- System Status: https://github:8443/setup/status
- Logs: https://github:8443/setup/logs

**Runners**:
- Prometheus metrics: http://runner:9100/metrics
- Runner status: `sudo runner-status`
- Logs: `sudo journalctl -u github-runner@* -f`

## Integration Guide

### Runner Groups

1. **Create Groups** in GitHub Enterprise:
   - Settings → Actions → Runner groups
   - Create: production, staging, development

2. **Assign Runners**:
   ```yaml
   # In workflow
   jobs:
     build:
       runs-on: [self-hosted, production]
   ```

### Workflow Examples

**Basic Build**:
```yaml
name: Build and Test
on: [push]

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: |
          docker build -t myapp .
          docker run myapp test
```

**Multi-Environment**:
```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy-staging:
    runs-on: [self-hosted, staging]
    steps:
      - uses: actions/checkout@v3
      - run: ./deploy.sh staging
      
  deploy-production:
    needs: deploy-staging
    runs-on: [self-hosted, production]
    environment: production
    steps:
      - uses: actions/checkout@v3
      - run: ./deploy.sh production
```

### Secrets Management

1. **Organization Secrets**:
   - Set at org level
   - Available to all repos

2. **Environment Secrets**:
   - Tied to environments
   - Approval requirements

3. **Runner Access**:
   ```yaml
   - name: Deploy
     env:
       API_KEY: ${{ secrets.API_KEY }}
     run: |
       ./deploy.sh
   ```

## Automation Scripts

### Complete Deployment Script

Create `Deploy-CompleteGitHub.ps1`:
```powershell
param(
    [string]$GitHubVHD,
    [string]$GitHubURL = "https://github.company.com",
    [int]$RunnerCount = 2
)

Write-Host "Deploying Complete GitHub Infrastructure" -ForegroundColor Magenta

# Deploy GitHub Enterprise
.\deploy\Deploy-GitHubEnterprise.ps1 -VHDPath $GitHubVHD

Write-Host "Please complete GitHub Enterprise setup at the console"
Write-Host "Press Enter when complete..."
Read-Host

# Deploy Runners
.\deploy\Deploy-GitHubRunners.ps1 `
  -Count $RunnerCount `
  -GitHubEnterpriseURL $GitHubURL

Write-Host "Waiting for runners to initialize (5 minutes)..."
Start-Sleep -Seconds 300

# Get registration token
Write-Host "Get registration token from: $GitHubURL/settings/actions/runners"
$Token = Read-Host "Enter token"

# Register runners
.\deploy\Register-RunnersToEnterprise.ps1 `
  -GitHubURL $GitHubURL `
  -Token $Token

# Show status
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Status
```

### Health Check Script

Create `Test-GitHubHealth.ps1`:
```powershell
# Quick health check
$Results = @{
    Timestamp = Get-Date
    Enterprise = $null
    Runners = @()
}

# Check Enterprise
try {
    $Response = Invoke-WebRequest -Uri "$GitHubURL/api/v3" -UseBasicParsing
    $Results.Enterprise = "Healthy"
} catch {
    $Results.Enterprise = "Unreachable"
}

# Check Runners
$RunnerVMs = Get-VM | Where-Object { $_.Name -like "*runner*" }
foreach ($VM in $RunnerVMs) {
    $Results.Runners += @{
        Name = $VM.Name
        State = $VM.State
        Health = if ($VM.State -eq 'Running') { "Healthy" } else { "Offline" }
    }
}

$Results | ConvertTo-Json
```

## Troubleshooting

### Common Issues

**GitHub Enterprise Won't Start**:
```powershell
# Check VM
Get-VM hsc-ctsc-github-enterprise | Select-Object *

# Check console
vmconnect.exe localhost hsc-ctsc-github-enterprise

# Common fixes:
# - Ensure VHD is Gen1 (not Gen2)
# - Check memory allocation
# - Verify network adapter
```

**Runners Not Registering**:
```bash
# On runner VM
sudo runner-status
sudo journalctl -u github-runner@1

# Test connectivity
curl -k https://github.company.com/api/v3

# Re-register
sudo systemctl stop github-runner@*
sudo register-runner
```

**Network Issues**:
```powershell
# Check vSwitches
Get-VMSwitch | Format-Table

# Test inter-VM connectivity
# From runner: ping github-enterprise-ip

# Check firewall
# On VM: sudo ufw status
```

**Performance Issues**:
```powershell
# Check resource usage
.\deploy\Manage-GitHubInfrastructure.ps1 -Action Health

# Common solutions:
# - Add more runner VMs
# - Increase VM resources
# - Check disk I/O
```

## Best Practices

### Design Principles

1. **Separation of Concerns**:
   - GitHub Enterprise = Control plane
   - Runners = Compute plane
   - Don't mix responsibilities

2. **Scalability**:
   - Start with 2 runner VMs
   - Add more as needed
   - Use runner groups for organization

3. **Security**:
   - Use internal network for VM communication
   - Ephemeral runners for isolation
   - Regular security updates

4. **Reliability**:
   - Automated backups
   - Monitoring and alerts
   - Documented procedures

### Operational Excellence

1. **Standardization**:
   - Consistent naming (hsc-ctsc-*)
   - Uniform VM configurations
   - Centralized management scripts

2. **Documentation**:
   - Document customizations
   - Maintain runbooks
   - Track configuration changes

3. **Testing**:
   - Test workflows in staging
   - Validate runner configurations
   - Practice recovery procedures

### Performance Optimization

1. **Runner Placement**:
   - Distribute load across VMs
   - Use labels for specialization
   - Monitor queue depth

2. **Caching**:
   - Docker layer caching
   - Dependency caching
   - Tool caching

3. **Resource Allocation**:
   - Right-size VMs
   - Monitor usage patterns
   - Scale based on metrics

## Reference

### PowerShell Commands

```powershell
# Deployment
Deploy-GitHubEnterprise.ps1    # Deploy GitHub Enterprise Server
Deploy-GitHubRunners.ps1       # Deploy runner VMs
Register-RunnersToEnterprise.ps1 # Register runners

# Management
Manage-GitHubInfrastructure.ps1 -Action [Status|Start|Stop|Health|Backup]

# Quick access
vmconnect.exe localhost "VM-Name"  # Console connection
Enter-PSSession -ComputerName VM-IP # Remote PowerShell
```

### Useful URLs

- GitHub Enterprise: `https://github.company.com`
- Management Console: `https://github.company.com:8443`
- Runner Status: `https://github.company.com/settings/actions/runners`
- API Endpoint: `https://github.company.com/api/v3`

### File Locations

**On GitHub Enterprise**:
- Logs: `/var/log/enterprise/`
- Backups: `/data/user/common/backup/`
- Config: `/data/user/common/github.conf`

**On Runner VMs**:
- Runner configs: `/home/runner*/actions-runner/`
- Work directories: `/home/runner*/work/`
- Logs: `/var/log/github-runner/`

### Related Documentation

- [GitHub Enterprise Deployment](GITHUB-ENTERPRISE-DEPLOYMENT.md) - Detailed deployment guide
- [GitHub Runners Guide](GITHUB-RUNNERS.md) - Runner configuration details
- [Windows Deployment Guide](WINDOWS-DEPLOYMENT.md) - Hyper-V procedures
- [Architecture Overview](ARCHITECTURE.md) - System design
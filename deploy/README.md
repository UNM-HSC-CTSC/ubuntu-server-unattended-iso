# Hyper-V Deployment Scripts

PowerShell scripts for deploying Ubuntu Server VMs on Windows Server 2019 with Hyper-V.

## Overview

These scripts automate the process of:
1. Building role-specific ISOs
2. Downloading ISOs from the repository
3. Creating and configuring Hyper-V VMs
4. Starting deployments

## Scripts

### Deploy-VM.ps1

Creates and configures a new Hyper-V VM with the specified ISO.

```powershell
# Basic deployment
.\Deploy-VM.ps1 -Name "hsc-ctsc-github-01" -ISOPath "C:\ISOs\ubuntu-github.iso"

# Advanced deployment with more resources
.\Deploy-VM.ps1 -Name "hsc-ctsc-tools-01" `
    -ISOPath "C:\ISOs\ubuntu-tools.iso" `
    -Memory 16GB `
    -CPUCount 8 `
    -DiskSize 500GB

# Custom network switch
.\Deploy-VM.ps1 -Name "test-vm" `
    -ISOPath "C:\ISOs\test.iso" `
    -SwitchName "Internal"
```

Features:
- Generation 2 VMs with UEFI
- Dynamic memory configuration
- Nested virtualization support
- Automatic boot from ISO
- Integration services enabled

### Build-RoleISO.ps1

Builds Ubuntu Server ISOs for specific roles.

```powershell
# Build using Docker
.\Build-RoleISO.ps1 -Role github -UseDocker

# Build using WSL2
.\Build-RoleISO.ps1 -Role tools

# Build bootstrap ISO
.\Build-RoleISO.ps1 -Role config-bootstrap

# Build with specific Ubuntu version
.\Build-RoleISO.ps1 -Role artifacts -Version 22.04.5

# Build and save to specific location
.\Build-RoleISO.ps1 -Role github -OutputPath "C:\ISOs"
```

Supported roles:
- `config-bootstrap` - Configuration server (self-contained)
- `repository-bootstrap` - Repository server
- `github` - Git repository server
- `tools` - Development and monitoring tools
- `artifacts` - Package repository

### Get-LatestISO.ps1

Downloads ISOs from the repository server.

```powershell
# List available ISOs
.\Get-LatestISO.ps1 -ListOnly

# Download latest version of a role
.\Get-LatestISO.ps1 -Role github

# Download specific version
.\Get-LatestISO.ps1 -Role tools -Version 1.2.3

# Download to specific location
.\Get-LatestISO.ps1 -Role artifacts -OutputPath "C:\ISOs"

# Use different repository server
.\Get-LatestISO.ps1 -Role github -RepositoryServer "repo.example.com"
```

## Typical Workflow

### 1. Initial Infrastructure Setup

```powershell
# Build config server ISO
.\Build-RoleISO.ps1 -Role config-bootstrap -UseDocker

# Deploy config server
.\Deploy-VM.ps1 -Name "hsc-ctsc-config" -ISOPath ".\ubuntu-24.04.2-config-bootstrap.iso"

# Build and deploy repository server
.\Build-RoleISO.ps1 -Role repository-bootstrap -UseDocker
.\Deploy-VM.ps1 -Name "hsc-ctsc-repository" -ISOPath ".\ubuntu-24.04.2-repository-bootstrap.iso"
```

### 2. Deploy Service Servers

```powershell
# After infrastructure is ready, build and upload ISOs to repository
# Then download and deploy as needed:

# Deploy GitHub server
.\Get-LatestISO.ps1 -Role github
.\Deploy-VM.ps1 -Name "hsc-ctsc-github-01" -ISOPath ".\github-latest.iso"

# Deploy Tools server with more resources
.\Get-LatestISO.ps1 -Role tools
.\Deploy-VM.ps1 -Name "hsc-ctsc-tools-01" `
    -ISOPath ".\tools-latest.iso" `
    -Memory 16GB `
    -CPUCount 8
```

### 3. Batch Deployment

```powershell
# Deploy multiple servers
$Servers = @(
    @{Name="hsc-ctsc-github-01"; Role="github"; Memory=8GB},
    @{Name="hsc-ctsc-tools-01"; Role="tools"; Memory=16GB},
    @{Name="hsc-ctsc-artifacts-01"; Role="artifacts"; Memory=8GB}
)

foreach ($Server in $Servers) {
    # Download ISO
    .\Get-LatestISO.ps1 -Role $Server.Role
    
    # Deploy VM
    .\Deploy-VM.ps1 -Name $Server.Name `
        -ISOPath ".\$($Server.Role)-latest.iso" `
        -Memory $Server.Memory
}
```

## Prerequisites

### For Deploy-VM.ps1
- Windows Server 2019 or later
- Hyper-V role installed
- Administrator privileges
- Virtual switch configured

### For Build-RoleISO.ps1
- **Option 1**: Docker Desktop (Windows)
- **Option 2**: WSL2 with Ubuntu
- **Option 3**: Remote Linux build server

### For Get-LatestISO.ps1
- Network access to repository server
- PowerShell 5.1 or later

## Troubleshooting

### VM Won't Boot
- Ensure Generation 2 VM settings
- Disable Secure Boot if needed
- Verify ISO is not corrupted

### Build Fails
- Check Docker/WSL2 is running
- Ensure sufficient disk space
- Verify network connectivity

### Download Fails
- Check repository server is accessible
- Verify role name is correct
- Use `-ListOnly` to see available ISOs

## Security Notes

1. **Change default passwords** immediately after deployment
2. **Secure the repository server** with authentication
3. **Use HTTPS** for production repository access
4. **Limit VM network access** until configuration is complete

## Integration with CI/CD

These scripts can be called from automation tools:

```yaml
# Example: Azure DevOps Pipeline
- task: PowerShell@2
  inputs:
    filePath: 'deploy/Get-LatestISO.ps1'
    arguments: '-Role $(role) -OutputPath $(Build.ArtifactStagingDirectory)'
```

## Related Documentation

- [Deployment Guide](../docs/DEPLOYMENT-GUIDE.md)
- [Bootstrap Guide](../docs/BOOTSTRAP-GUIDE.md)
- [Architecture Overview](../docs/ARCHITECTURE.md)
# Quick Start Guide - Windows Server with Hyper-V

Rapid deployment guide for experienced administrators. For detailed explanations, see [Windows Deployment Guide](WINDOWS-DEPLOYMENT.md).

## Prerequisites
- Windows Server 2019+ with Hyper-V
- Administrator access
- External virtual switch configured
- Internet connectivity

## 1. Setup Build Environment (10 minutes)

```powershell
# Run as Administrator

# Install Git
Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe" -OutFile "$env:TEMP\git.exe"
Start-Process "$env:TEMP\git.exe" -ArgumentList "/VERYSILENT" -Wait

# Install Docker Desktop
Invoke-WebRequest "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -OutFile "$env:TEMP\docker.exe"
Start-Process "$env:TEMP\docker.exe" -ArgumentList "install","--quiet","--accept-license" -Wait

# Restart required after Docker install
Restart-Computer -Force
```

## 2. Clone and Build (After Restart)

```powershell
# Clone repository
New-Item -Path "C:\ISO-Builder" -ItemType Directory -Force
cd C:\ISO-Builder
git clone https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso.git
cd ubuntu-server-unattended-iso

# Create ISOs directory
New-Item -Path "C:\ISOs" -ItemType Directory -Force

# Build config server ISO
.\deploy\Build-RoleISO.ps1 -Role config-bootstrap -UseDocker -OutputPath "C:\ISOs"
```

## 3. Deploy Config Server

```powershell
# Deploy VM
$ISO = Get-ChildItem "C:\ISOs\config-bootstrap-*.iso" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-config" -ISOPath $ISO.FullName -Memory 4GB -CPUCount 2 -DiskSize 50GB

# Start VM when prompted: Y
# Connect to console
vmconnect.exe localhost "hsc-ctsc-config"
```

## 4. Wait for Installation (15-20 minutes)
- Automated Ubuntu installation
- Automatic reboot
- Cloud-init configuration
- Wait for login prompt

## 5. Get IP and Verify

```powershell
# Get IP from Hyper-V
Get-VM "hsc-ctsc-config" | Select-Object -ExpandProperty NetworkAdapters

# Store IP
$ConfigIP = "192.168.x.x"  # Replace with actual IP

# Verify services
Invoke-WebRequest "http://$ConfigIP/health" -UseBasicParsing
```

## 6. Initialize Ansible Repository

```powershell
# Upload Ansible configs
cd C:\ISO-Builder
git clone http://${ConfigIP}/git/ansible-config.git
cd ansible-config
Copy-Item ..\ubuntu-server-unattended-iso\ansible\* . -Recurse
git add .
git config user.email "admin@health.unm.edu"
git config user.name "Administrator"
git commit -m "Initial config"
git push origin main
```

## 7. Update DNS
Create A record: `hsc-ctsc-config.health.unm.edu` → Config Server IP

## 8. Deploy Additional Servers

```powershell
# Build repository server
.\deploy\Build-RoleISO.ps1 -Role repository-bootstrap -UseDocker -OutputPath "C:\ISOs"
$RepoISO = Get-ChildItem "C:\ISOs\repository-bootstrap-*.iso" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-repository" -ISOPath $RepoISO.FullName -Memory 8GB -DiskSize 500GB

# Build service servers
.\deploy\Build-RoleISO.ps1 -Role github -UseDocker -OutputPath "C:\ISOs"
.\deploy\Build-RoleISO.ps1 -Role tools -UseDocker -OutputPath "C:\ISOs"

# Deploy service servers
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-github-01" -ISOPath "C:\ISOs\github-*.iso"
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-tools-01" -ISOPath "C:\ISOs\tools-*.iso" -Memory 16GB
```

## Common Commands Reference

### Check VM Status
```powershell
Get-VM | Where-Object {$_.Name -like "hsc-ctsc-*"} | Format-Table Name, State, CPUUsage, MemoryAssigned
```

### Connect to VM Console
```powershell
vmconnect.exe localhost "VM-NAME"
```

### Build ISO for Any Role
```powershell
.\deploy\Build-RoleISO.ps1 -Role [config-bootstrap|repository-bootstrap|github|tools|artifacts] -UseDocker
```

### Deploy VM with Custom Resources
```powershell
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-name" -ISOPath "path\to\iso" -Memory 8GB -CPUCount 4 -DiskSize 100GB
```

### SSH to Servers (after deployment)
```powershell
ssh configadmin@hsc-ctsc-config.health.unm.edu    # Password: ChangeMe123! (change on first login)
ssh repoadmin@hsc-ctsc-repository.health.unm.edu  # Password: ChangeMe123!
ssh sysadmin@hsc-ctsc-github-01.health.unm.edu    # Password: ChangeMe123!
```

## Troubleshooting Quick Fixes

### Docker Not Starting
```powershell
Start-Service "Docker Desktop Service"
# Wait 30 seconds
docker version
```

### No IP Address on VM
```powershell
# Check virtual switch
Get-VMSwitch
# Verify F5 DHCP is working
# Check VM network adapter
Get-VMNetworkAdapter -VMName "hsc-ctsc-config"
```

### Can't Access Web Interface
```powershell
# Test connectivity
Test-NetConnection -ComputerName $ConfigIP -Port 80
# If fails, wait for cloud-init to complete (up to 15 minutes after boot)
```

## Next Steps
1. Change all default passwords
2. Configure SSL certificates
3. Set up monitoring
4. Document customizations

## See Also
- [Windows Deployment Guide](WINDOWS-DEPLOYMENT.md) - Detailed explanations
- [PowerShell Scripts](../deploy/README.md) - Script documentation
- [Bootstrap Guide](BOOTSTRAP-GUIDE.md) - Architecture details
<#
.SYNOPSIS
    Deploys GitHub Actions runner VMs for GitHub Enterprise Server
.DESCRIPTION
    This script deploys one or more VMs configured as GitHub Actions runners.
    It uses the Ubuntu Server Unattended ISO Builder to create properly configured runner VMs.
.PARAMETER VMNamePrefix
    Prefix for VM names (will append -01, -02, etc.)
.PARAMETER Count
    Number of runner VMs to deploy (default: 1)
.PARAMETER ISOPath
    Path to the GitHub runner ISO (will build if not provided)
.PARAMETER Memory
    Amount of RAM per VM (default: 16GB)
.PARAMETER CPUCount
    Number of vCPUs per VM (default: 8)
.PARAMETER DiskSize
    Size of disk per VM (default: 200GB)
.PARAMETER VMPath
    Base path where VM files will be stored
.PARAMETER ExternalSwitch
    Name of external virtual switch (default: External)
.PARAMETER InternalSwitch
    Name of internal virtual switch for VM communication
.PARAMETER GitHubEnterpriseURL
    URL of your GitHub Enterprise Server instance
.PARAMETER StartVMs
    Start the VMs after creation (default: true)
.PARAMETER RunnersPerVM
    Number of runners per VM (default: 4)
.EXAMPLE
    .\Deploy-GitHubRunners.ps1 -Count 2 -GitHubEnterpriseURL "https://github.company.com"
.EXAMPLE
    .\Deploy-GitHubRunners.ps1 -VMNamePrefix "hsc-ctsc-runners" -Count 3 -Memory 32GB
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$VMNamePrefix = "hsc-ctsc-github-runners",
    
    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$Count = 1,
    
    [Parameter()]
    [string]$ISOPath,
    
    [Parameter()]
    [ValidateRange(8GB, 256GB)]
    [Int64]$Memory = 16GB,
    
    [Parameter()]
    [ValidateRange(4, 32)]
    [int]$CPUCount = 8,
    
    [Parameter()]
    [ValidateRange(100GB, 2TB)]
    [Int64]$DiskSize = 200GB,
    
    [Parameter()]
    [string]$VMPath = "C:\VMs",
    
    [Parameter()]
    [string]$ExternalSwitch = "External",
    
    [Parameter()]
    [string]$InternalSwitch = "Internal",
    
    [Parameter()]
    [string]$GitHubEnterpriseURL,
    
    [Parameter()]
    [bool]$StartVMs = $true,
    
    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$RunnersPerVM = 4
)

# Requires elevation
#Requires -RunAsAdministrator

# Helper functions
function Write-StepHeader {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

# Function to build ISO if needed
function Build-RunnerISO {
    param([string]$OutputPath)
    
    Write-StepHeader "Building GitHub Runner ISO"
    
    # Look for the ISO builder
    $ISOBuilderPaths = @(
        ".\docker-build.ps1",
        "..\docker-build.ps1",
        "C:\ISO-Builder\ubuntu-server-unattended-iso\docker-build.ps1"
    )
    
    $BuildScript = $null
    foreach ($Path in $ISOBuilderPaths) {
        if (Test-Path $Path) {
            $BuildScript = Resolve-Path $Path
            break
        }
    }
    
    if (!$BuildScript) {
        throw "Cannot find ISO builder. Please specify -ISOPath or ensure the ISO builder is available."
    }
    
    Write-Info "Found ISO builder: $BuildScript"
    
    # Build the ISO
    Push-Location (Split-Path $BuildScript -Parent)
    try {
        & $BuildScript -OutputPath $OutputPath
        
        # Find the created ISO
        $CreatedISO = Get-ChildItem -Path $OutputPath -Filter "*github*.iso" | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
            
        if (!$CreatedISO) {
            throw "ISO build completed but no ISO file found"
        }
        
        return $CreatedISO.FullName
    } finally {
        Pop-Location
    }
}

# Main script
try {
    Write-Host @"
GitHub Runners Deployment Script
================================
This script will deploy $Count GitHub Actions runner VM(s)
Each VM will run $RunnersPerVM runners
"@ -ForegroundColor Magenta

    # Validate prerequisites
    Write-StepHeader "Validating Prerequisites"
    
    # Check Hyper-V
    if (!(Get-WindowsFeature -Name Hyper-V | Where-Object {$_.InstallState -eq "Installed"})) {
        throw "Hyper-V is not installed. Please install the Hyper-V role first."
    }
    Write-Success "Hyper-V is installed"
    
    # Check virtual switches
    $ExtSwitch = Get-VMSwitch -Name $ExternalSwitch -ErrorAction SilentlyContinue
    if (!$ExtSwitch) {
        throw "External switch '$ExternalSwitch' not found."
    }
    Write-Success "External switch found: $ExternalSwitch"
    
    if ($InternalSwitch) {
        $IntSwitch = Get-VMSwitch -Name $InternalSwitch -ErrorAction SilentlyContinue
        if ($IntSwitch) {
            Write-Success "Internal switch found: $InternalSwitch"
        } else {
            Write-Info "Internal switch '$InternalSwitch' not found. VMs will only use external network."
        }
    }
    
    # Handle ISO
    if (!$ISOPath) {
        # Build ISO if not provided
        $ISODir = "$VMPath\ISOs"
        if (!(Test-Path $ISODir)) {
            New-Item -Path $ISODir -ItemType Directory -Force | Out-Null
        }
        
        $ISOPath = Build-RunnerISO -OutputPath $ISODir
    } else {
        # Validate provided ISO
        if (!(Test-Path $ISOPath)) {
            throw "ISO file not found: $ISOPath"
        }
    }
    
    Write-Success "Using ISO: $(Split-Path $ISOPath -Leaf)"
    
    # Check for GitHub Enterprise URL
    if ($GitHubEnterpriseURL) {
        Write-Success "GitHub Enterprise URL: $GitHubEnterpriseURL"
    } else {
        Write-Info "No GitHub Enterprise URL specified. Runners will need manual configuration."
    }
    
    # Deploy VMs
    Write-StepHeader "Deploying Runner VMs"
    
    $DeployedVMs = @()
    
    for ($i = 1; $i -le $Count; $i++) {
        $VMNumber = $i.ToString("00")
        $VMName = "$VMNamePrefix-$VMNumber"
        
        Write-Info "Deploying VM $i of $Count : $VMName"
        
        # Check if VM already exists
        if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
            Write-ErrorMessage "VM '$VMName' already exists. Skipping..."
            continue
        }
        
        # Create VM directory
        $ThisVMPath = "$VMPath\$VMName"
        if (!(Test-Path $ThisVMPath)) {
            New-Item -Path $ThisVMPath -ItemType Directory -Force | Out-Null
        }
        
        # Create VM
        $VMParams = @{
            Name = $VMName
            MemoryStartupBytes = $Memory
            NewVHDPath = "$ThisVMPath\$VMName.vhdx"
            NewVHDSizeBytes = $DiskSize
            Generation = 2
            SwitchName = $ExternalSwitch
            Path = $VMPath
        }
        
        $VM = New-VM @VMParams
        
        # Configure VM
        Set-VMProcessor -VMName $VMName -Count $CPUCount
        Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -MinimumBytes 4GB -MaximumBytes $Memory
        
        # Configure firmware for Gen2 VM
        Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
        
        # Add DVD drive and mount ISO
        Add-VMDvdDrive -VMName $VMName -Path $ISOPath
        
        # Set boot order to DVD first
        $DVDDrive = Get-VMDvdDrive -VMName $VMName
        Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive
        
        # Add internal network adapter if available
        if ($IntSwitch) {
            Add-VMNetworkAdapter -VMName $VMName -SwitchName $InternalSwitch
        }
        
        # Enable nested virtualization (for Docker)
        Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
        
        # Configure automatic actions
        Set-VM -VMName $VMName `
            -AutomaticStartAction Start `
            -AutomaticStartDelay (60 + ($i * 30)) `
            -AutomaticStopAction ShutDown
        
        # Enable guest services
        Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
        
        Write-Success "VM created: $VMName"
        
        $DeployedVMs += @{
            Name = $VMName
            Path = $ThisVMPath
            Number = $VMNumber
        }
    }
    
    # Start VMs if requested
    if ($StartVMs -and $DeployedVMs.Count -gt 0) {
        Write-StepHeader "Starting Virtual Machines"
        
        foreach ($VM in $DeployedVMs) {
            Write-Info "Starting $($VM.Name)..."
            Start-VM -Name $VM.Name
            
            # Stagger startup to avoid resource contention
            if ($VM -ne $DeployedVMs[-1]) {
                Start-Sleep -Seconds 30
            }
        }
        
        Write-Success "All VMs started"
    }
    
    # Create runner configuration script
    if ($GitHubEnterpriseURL -and $DeployedVMs.Count -gt 0) {
        Write-StepHeader "Creating Configuration Scripts"
        
        $ConfigScript = @"
# GitHub Runner Configuration Helper
# Run this after VMs complete initial setup

`$GitHubURL = "$GitHubEnterpriseURL"
`$VMs = @(
$(foreach ($VM in $DeployedVMs) {
    "    '$($VM.Name)'"
})
)

Write-Host "This script will help configure runners for GitHub Enterprise" -ForegroundColor Cyan
Write-Host "GitHub Enterprise URL: `$GitHubURL" -ForegroundColor Yellow
Write-Host ""
Write-Host "Prerequisites:" -ForegroundColor Yellow
Write-Host "1. VMs must complete cloud-init (check with: ssh sysadmin@VM_IP)" -ForegroundColor Yellow
Write-Host "2. You need a registration token from GitHub Enterprise" -ForegroundColor Yellow
Write-Host "3. Get token from: `$GitHubURL/settings/actions/runners/new" -ForegroundColor Yellow
Write-Host ""

`$Token = Read-Host "Enter registration token"

foreach (`$VMName in `$VMs) {
    Write-Host "`nConfiguring `$VMName..." -ForegroundColor Cyan
    
    # Get VM IP
    `$VM = Get-VM -Name `$VMName
    `$IP = (`$VM | Get-VMNetworkAdapter | Select-Object -First 1).IPAddresses | Where-Object { `$_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1
    
    if (`$IP) {
        Write-Host "VM IP: `$IP" -ForegroundColor Green
        Write-Host "Run on the VM: sudo register-runner" -ForegroundColor Yellow
        Write-Host "URL: `$GitHubURL" -ForegroundColor Yellow
        Write-Host "Token: `$Token" -ForegroundColor Yellow
    } else {
        Write-Host "Cannot get IP for `$VMName. Check VM status." -ForegroundColor Red
    }
}
"@
        
        $ConfigScriptPath = "$VMPath\Configure-Runners.ps1"
        $ConfigScript | Out-File -FilePath $ConfigScriptPath -Encoding UTF8
        Write-Success "Created configuration helper: $ConfigScriptPath"
    }
    
    # Display summary
    Write-StepHeader "Deployment Complete!"
    
    Write-Host @"

Deployment Summary:
- VMs Deployed: $($DeployedVMs.Count)
- Memory per VM: $([math]::Round($Memory / 1GB, 0)) GB
- CPUs per VM: $CPUCount
- Disk per VM: $([math]::Round($DiskSize / 1GB, 0)) GB
- Runners per VM: $RunnersPerVM
- Total Runners: $($DeployedVMs.Count * $RunnersPerVM)

Deployed VMs:
"@ -ForegroundColor Green

    foreach ($VM in $DeployedVMs) {
        Write-Host "  - $($VM.Name)" -ForegroundColor Green
    }
    
    Write-Host @"

Next Steps:
1. Wait for VMs to complete initial setup (~10-15 minutes)
   - Check console: vmconnect.exe localhost "VM_NAME"
   - Wait for login prompt

2. Get VM IP addresses:
   - Check Hyper-V Manager
   - Or run: Get-VM | Get-VMNetworkAdapter | Select VMName, IPAddresses

3. SSH to each VM:
   ssh sysadmin@<VM_IP>
   (Default password: ChangeMe123!)

4. Register runners with GitHub Enterprise:
$(if ($GitHubEnterpriseURL) {
@"
   Run the helper script: $VMPath\Configure-Runners.ps1
   Or manually on each VM: sudo register-runner
"@
} else {
"   On each VM run: sudo register-runner"
})

5. Verify runners in GitHub Enterprise:
   $(if ($GitHubEnterpriseURL) { "$GitHubEnterpriseURL/settings/actions/runners" } else { "https://YOUR_GITHUB/settings/actions/runners" })

For detailed instructions, see:
docs\GITHUB-ENTERPRISE-DEPLOYMENT.md

"@ -ForegroundColor Cyan

} catch {
    Write-ErrorMessage $_.Exception.Message
    Write-Host "`nDeployment failed. Please check the error message above." -ForegroundColor Red
    exit 1
}
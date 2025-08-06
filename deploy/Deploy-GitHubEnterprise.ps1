<#
.SYNOPSIS
    Deploys GitHub Enterprise Server on Hyper-V
.DESCRIPTION
    This script automates the deployment of GitHub Enterprise Server virtual appliance on Hyper-V.
    It creates the VM, configures resources, and prepares it for initial setup.
.PARAMETER VMName
    Name of the virtual machine (default: hsc-ctsc-github-enterprise)
.PARAMETER VHDPath
    Path to the GitHub Enterprise VHD file
.PARAMETER Memory
    Amount of RAM to allocate (default: 64GB)
.PARAMETER CPUCount
    Number of vCPUs to allocate (default: 16)
.PARAMETER DataDiskSize
    Size of the data disk for user data (default: 400GB)
.PARAMETER VMPath
    Path where VM files will be stored (default: C:\VMs\GitHub-Enterprise)
.PARAMETER ExternalSwitch
    Name of external virtual switch (default: External)
.PARAMETER InternalSwitch
    Name of internal virtual switch for VM communication (default: Internal)
.PARAMETER CreateInternalSwitch
    Create the internal switch if it doesn't exist
.EXAMPLE
    .\Deploy-GitHubEnterprise.ps1 -VHDPath "C:\Downloads\github-enterprise.vhd"
.EXAMPLE
    .\Deploy-GitHubEnterprise.ps1 -VHDPath "C:\Downloads\github-enterprise.vhd" -Memory 128GB -CPUCount 32
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$VMName = "hsc-ctsc-github-enterprise",
    
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$VHDPath,
    
    [Parameter()]
    [ValidateRange(32GB, 1TB)]
    [Int64]$Memory = 64GB,
    
    [Parameter()]
    [ValidateRange(8, 64)]
    [int]$CPUCount = 16,
    
    [Parameter()]
    [ValidateRange(200GB, 4TB)]
    [Int64]$DataDiskSize = 400GB,
    
    [Parameter()]
    [string]$VMPath = "C:\VMs\GitHub-Enterprise",
    
    [Parameter()]
    [string]$ExternalSwitch = "External",
    
    [Parameter()]
    [string]$InternalSwitch = "Internal",
    
    [Parameter()]
    [switch]$CreateInternalSwitch,
    
    [Parameter()]
    [switch]$StartVM = $true
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

# Main script
try {
    Write-Host @"
GitHub Enterprise Server Deployment Script
=========================================
This script will deploy GitHub Enterprise Server on Hyper-V
"@ -ForegroundColor Magenta

    # Validate prerequisites
    Write-StepHeader "Validating Prerequisites"
    
    # Check Hyper-V
    if (!(Get-WindowsFeature -Name Hyper-V | Where-Object {$_.InstallState -eq "Installed"})) {
        throw "Hyper-V is not installed. Please install the Hyper-V role first."
    }
    Write-Success "Hyper-V is installed"
    
    # Check if VM already exists
    if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
        throw "VM '$VMName' already exists. Please remove it first or choose a different name."
    }
    Write-Success "VM name is available"
    
    # Validate VHD
    $VHDItem = Get-Item $VHDPath
    if ($VHDItem.Extension -ne ".vhd") {
        throw "GitHub Enterprise requires a VHD file (not VHDX)"
    }
    Write-Success "VHD file validated: $($VHDItem.Name)"
    Write-Info "VHD Size: $([math]::Round($VHDItem.Length / 1GB, 2)) GB"
    
    # Check virtual switches
    $ExtSwitch = Get-VMSwitch -Name $ExternalSwitch -ErrorAction SilentlyContinue
    if (!$ExtSwitch) {
        throw "External switch '$ExternalSwitch' not found. Please create it first or specify a different switch."
    }
    Write-Success "External switch found: $ExternalSwitch"
    
    $IntSwitch = Get-VMSwitch -Name $InternalSwitch -ErrorAction SilentlyContinue
    if (!$IntSwitch) {
        if ($CreateInternalSwitch) {
            Write-Info "Creating internal switch: $InternalSwitch"
            New-VMSwitch -Name $InternalSwitch -SwitchType Internal
            Write-Success "Internal switch created"
        } else {
            Write-Info "Internal switch '$InternalSwitch' not found. Use -CreateInternalSwitch to create it."
        }
    } else {
        Write-Success "Internal switch found: $InternalSwitch"
    }
    
    # Create VM directory structure
    Write-StepHeader "Creating VM Directory Structure"
    
    $Directories = @(
        $VMPath,
        "$VMPath\Virtual Hard Disks",
        "$VMPath\Snapshots"
    )
    
    foreach ($Dir in $Directories) {
        if (!(Test-Path $Dir)) {
            New-Item -Path $Dir -ItemType Directory -Force | Out-Null
            Write-Success "Created: $Dir"
        }
    }
    
    # Copy VHD to VM directory
    Write-StepHeader "Preparing Virtual Hard Disk"
    
    $DestinationVHD = "$VMPath\Virtual Hard Disks\$VMName-system.vhd"
    Write-Info "Copying VHD to VM directory (this may take several minutes)..."
    
    $CopyJob = Start-Job -ScriptBlock {
        param($Source, $Destination)
        Copy-Item -Path $Source -Destination $Destination -Force
    } -ArgumentList $VHDPath, $DestinationVHD
    
    while ($CopyJob.State -eq 'Running') {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }
    Write-Host ""
    
    if ($CopyJob.State -eq 'Failed') {
        throw "Failed to copy VHD: $($CopyJob.ChildJobs[0].Error)"
    }
    
    Write-Success "VHD copied successfully"
    
    # Create the VM
    Write-StepHeader "Creating Virtual Machine"
    
    $VMParams = @{
        Name = $VMName
        MemoryStartupBytes = $Memory
        VHDPath = $DestinationVHD
        Generation = 1  # GitHub Enterprise requires Gen 1
        SwitchName = $ExternalSwitch
        Path = $VMPath
    }
    
    $VM = New-VM @VMParams
    Write-Success "VM created: $VMName"
    
    # Configure VM
    Write-StepHeader "Configuring Virtual Machine"
    
    # Set processor count
    Set-VMProcessor -VMName $VMName -Count $CPUCount
    Write-Success "Configured $CPUCount vCPUs"
    
    # Disable dynamic memory (recommended for GitHub Enterprise)
    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
    Write-Success "Configured static memory: $([math]::Round($Memory / 1GB, 0)) GB"
    
    # Enable nested virtualization (required for Actions)
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
    Write-Success "Enabled nested virtualization for Actions"
    
    # Create and attach data disk
    Write-StepHeader "Creating Data Disk"
    
    $DataDiskPath = "$VMPath\Virtual Hard Disks\$VMName-data.vhdx"
    New-VHD -Path $DataDiskPath -SizeBytes $DataDiskSize -Dynamic | Out-Null
    Add-VMHardDiskDrive -VMName $VMName -Path $DataDiskPath
    Write-Success "Created and attached data disk: $([math]::Round($DataDiskSize / 1GB, 0)) GB"
    
    # Add internal network adapter if switch exists
    if ($IntSwitch) {
        Add-VMNetworkAdapter -VMName $VMName -SwitchName $InternalSwitch
        Write-Success "Added internal network adapter"
    }
    
    # Configure automatic actions
    Set-VM -VMName $VMName `
        -AutomaticStartAction Start `
        -AutomaticStartDelay 60 `
        -AutomaticStopAction ShutDown
    Write-Success "Configured automatic start/stop actions"
    
    # Enable guest services
    Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
    Write-Success "Enabled guest services"
    
    # Start VM if requested
    if ($StartVM) {
        Write-StepHeader "Starting Virtual Machine"
        Start-VM -VMName $VMName
        Write-Success "VM started successfully"
        
        # Wait a moment for VM to initialize
        Write-Info "Waiting for VM to initialize..."
        Start-Sleep -Seconds 10
    }
    
    # Display summary and next steps
    Write-StepHeader "Deployment Complete!"
    
    Write-Host @"

VM Configuration Summary:
- Name: $VMName
- Memory: $([math]::Round($Memory / 1GB, 0)) GB
- CPUs: $CPUCount
- System Disk: $([math]::Round($VHDItem.Length / 1GB, 2)) GB
- Data Disk: $([math]::Round($DataDiskSize / 1GB, 0)) GB
- External Network: $ExternalSwitch
$(if ($IntSwitch) { "- Internal Network: $InternalSwitch" })

Next Steps:
1. Connect to the VM console:
   vmconnect.exe localhost "$VMName"

2. Wait for the blue setup screen

3. Get the VM's IP address:
   - Press 'S' for shell access
   - Run: ip addr show
   - Note the IP address

4. Open a web browser and navigate to:
   http://<IP_ADDRESS>

5. Follow the setup wizard:
   - Upload your license file
   - Set management console password
   - Configure hostname
   - Create admin account

6. Enable GitHub Actions in the Management Console

For detailed instructions, see:
docs\GITHUB-ENTERPRISE-DEPLOYMENT.md

"@ -ForegroundColor Green

    # Create quick connect script
    $ConnectScript = @"
# Quick connect to GitHub Enterprise VM
vmconnect.exe localhost "$VMName"
"@
    
    $ConnectScriptPath = "$VMPath\Connect-GitHubEnterprise.ps1"
    $ConnectScript | Out-File -FilePath $ConnectScriptPath -Encoding UTF8
    Write-Info "Created quick connect script: $ConnectScriptPath"
    
} catch {
    Write-ErrorMessage $_.Exception.Message
    Write-Host "`nDeployment failed. Please check the error message above." -ForegroundColor Red
    exit 1
}
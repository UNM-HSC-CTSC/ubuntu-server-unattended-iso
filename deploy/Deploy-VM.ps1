<#
.SYNOPSIS
    Deploy a new VM on Hyper-V with specified ISO and configuration

.DESCRIPTION
    Creates and configures a new Hyper-V VM with the specified ISO attached.
    Supports Generation 2 VMs with UEFI boot.

.PARAMETER Name
    Name of the VM to create

.PARAMETER ISOPath
    Path to the Ubuntu Server ISO file

.PARAMETER Memory
    Amount of memory to allocate (default: 4GB)

.PARAMETER DiskSize
    Size of the virtual hard disk (default: 100GB)

.PARAMETER CPUCount
    Number of virtual CPUs (default: 2)

.PARAMETER SwitchName
    Name of the Hyper-V virtual switch (default: "External")

.PARAMETER VHDPath
    Custom path for the VHD file (optional)

.EXAMPLE
    .\Deploy-VM.ps1 -Name "hsc-ctsc-github-01" -ISOPath "C:\ISOs\ubuntu-github.iso"

.EXAMPLE
    .\Deploy-VM.ps1 -Name "hsc-ctsc-tools-01" -ISOPath "C:\ISOs\ubuntu-tools.iso" -Memory 16GB -CPUCount 8
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$ISOPath,
    
    [int64]$Memory = 4GB,
    
    [int64]$DiskSize = 100GB,
    
    [int]$CPUCount = 2,
    
    [string]$SwitchName = "External",
    
    [string]$VHDPath = ""
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
$Green = @{ForegroundColor = 'Green'}
$Yellow = @{ForegroundColor = 'Yellow'}
$Red = @{ForegroundColor = 'Red'}

function Write-Status {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" @Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WARNING: $Message" @Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $Message" @Red
}

try {
    # Check if running as Administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "This script must be run as Administrator"
    }

    # Check if Hyper-V is installed
    if (-not (Get-WindowsFeature -Name Hyper-V -ErrorAction SilentlyContinue | Where-Object {$_.Installed})) {
        throw "Hyper-V is not installed on this system"
    }

    Write-Status "Starting VM deployment for: $Name"

    # Check if VM already exists
    if (Get-VM -Name $Name -ErrorAction SilentlyContinue) {
        throw "VM '$Name' already exists. Please remove it first or choose a different name."
    }

    # Check if switch exists
    if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
        throw "Virtual switch '$SwitchName' not found. Available switches: $(Get-VMSwitch | Select-Object -ExpandProperty Name -Join ', ')"
    }

    # Set default VHD path if not specified
    if ([string]::IsNullOrEmpty($VHDPath)) {
        $DefaultVMPath = (Get-VMHost).VirtualMachinePath
        $VHDPath = Join-Path $DefaultVMPath "$Name\$Name.vhdx"
    }

    # Create directory for VHD if it doesn't exist
    $VHDDirectory = Split-Path -Parent $VHDPath
    if (-not (Test-Path $VHDDirectory)) {
        Write-Status "Creating directory: $VHDDirectory"
        New-Item -Path $VHDDirectory -ItemType Directory -Force | Out-Null
    }

    # Create the VM
    Write-Status "Creating VM: $Name"
    $VM = New-VM -Name $Name `
        -MemoryStartupBytes $Memory `
        -Generation 2 `
        -NewVHDPath $VHDPath `
        -NewVHDSizeBytes $DiskSize `
        -SwitchName $SwitchName

    Write-Status "VM created successfully"

    # Configure VM settings
    Write-Status "Configuring VM settings..."
    
    # Set processor count
    Set-VMProcessor -VMName $Name -Count $CPUCount
    Write-Status "Set CPU count to: $CPUCount"

    # Configure memory (enable dynamic memory)
    Set-VMMemory -VMName $Name `
        -DynamicMemoryEnabled $true `
        -MinimumBytes ($Memory / 2) `
        -StartupBytes $Memory `
        -MaximumBytes ($Memory * 2)
    Write-Status "Configured dynamic memory"

    # Add DVD drive with ISO
    Write-Status "Attaching ISO: $ISOPath"
    Add-VMDvdDrive -VMName $Name -Path $ISOPath
    
    # Get the DVD drive
    $DVDDrive = Get-VMDvdDrive -VMName $Name

    # Configure firmware to boot from DVD
    Write-Status "Configuring boot order..."
    Set-VMFirmware -VMName $Name -FirstBootDevice $DVDDrive -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"

    # Enable nested virtualization (useful for tools server)
    Set-VMProcessor -VMName $Name -ExposeVirtualizationExtensions $true
    Write-Status "Enabled nested virtualization"

    # Enable integration services
    Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"
    Write-Status "Enabled integration services"

    # Configure automatic start action
    Set-VM -VMName $Name -AutomaticStartAction StartIfRunning -AutomaticStopAction ShutDown
    
    # Configure checkpoints
    Set-VM -VMName $Name -CheckpointType Disabled
    Write-Status "Disabled automatic checkpoints"

    # Display VM information
    Write-Host "`n=== VM Configuration ===" @Green
    Write-Host "Name:       $Name"
    Write-Host "Memory:     $($Memory / 1GB) GB"
    Write-Host "CPUs:       $CPUCount"
    Write-Host "Disk:       $($DiskSize / 1GB) GB"
    Write-Host "Network:    $SwitchName"
    Write-Host "ISO:        $(Split-Path -Leaf $ISOPath)"
    Write-Host "VHD Path:   $VHDPath"
    Write-Host "========================`n" @Green

    # Ask if user wants to start the VM
    $Start = Read-Host "Do you want to start the VM now? (Y/N)"
    if ($Start -eq 'Y' -or $Start -eq 'y') {
        Write-Status "Starting VM..."
        Start-VM -Name $Name
        
        Write-Host "`n=== VM Started Successfully ===" @Green
        Write-Host "To connect to the VM console, run:" @Yellow
        Write-Host "vmconnect.exe localhost `"$Name`"" @Yellow
        Write-Host "Or use Hyper-V Manager" @Yellow
        
        # Wait a moment and show VM state
        Start-Sleep -Seconds 2
        Get-VM -Name $Name | Format-Table Name, State, CPUUsage, MemoryAssigned, Uptime -AutoSize
    }
    else {
        Write-Host "`nVM created but not started. To start later, run:" @Yellow
        Write-Host "Start-VM -Name `"$Name`"" @Yellow
    }

    # Create a connection script
    $ConnectionScript = @"
# Connect to $Name
vmconnect.exe localhost "$Name"
"@
    $ScriptPath = Join-Path $VHDDirectory "Connect-$Name.ps1"
    $ConnectionScript | Out-File -FilePath $ScriptPath -Encoding UTF8
    Write-Status "Created connection script: $ScriptPath"

    Write-Host "`n=== Deployment Complete ===" @Green

} catch {
    Write-Error $_.Exception.Message
    Write-Host "`nDeployment failed. Please check the error message above." @Red
    exit 1
}
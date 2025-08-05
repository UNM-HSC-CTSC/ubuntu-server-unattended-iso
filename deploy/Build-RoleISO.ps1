<#
.SYNOPSIS
    Build an Ubuntu Server ISO for a specific role

.DESCRIPTION
    Builds a custom Ubuntu Server ISO with the specified role configuration.
    Can run locally or connect to a remote build server.

.PARAMETER Role
    The server role to build (e.g., github, tools, artifacts, config-bootstrap)

.PARAMETER Version
    Ubuntu version to use (default: 24.04.2)

.PARAMETER OutputPath
    Where to save the ISO (default: current directory)

.PARAMETER BuildServer
    Remote build server to use (optional, for Linux build server)

.PARAMETER UseDocker
    Use Docker to build the ISO (requires Docker Desktop)

.EXAMPLE
    .\Build-RoleISO.ps1 -Role github

.EXAMPLE
    .\Build-RoleISO.ps1 -Role tools -Version 22.04.5 -OutputPath C:\ISOs

.EXAMPLE
    .\Build-RoleISO.ps1 -Role config-bootstrap -UseDocker
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('config-bootstrap', 'repository-bootstrap', 'github', 'tools', 'artifacts')]
    [string]$Role,
    
    [string]$Version = "24.04.2",
    
    [string]$OutputPath = $PWD,
    
    [string]$BuildServer = "",
    
    [switch]$UseDocker
)

$ErrorActionPreference = "Stop"

# Colors
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
    Write-Status "Building ISO for role: $Role"
    
    # Determine role type
    $IsBootstrap = $Role -like "*-bootstrap"
    $ProfileName = if ($IsBootstrap) { $Role } else { "$Role-server" }
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Generate output filename
    $ISOName = "ubuntu-$Version-$Role.iso"
    $ISOFullPath = Join-Path $OutputPath $ISOName
    
    if ($UseDocker) {
        Write-Status "Using Docker build method"
        
        # Check if Docker is available
        $DockerVersion = docker version --format '{{.Client.Version}}' 2>$null
        if (-not $DockerVersion) {
            throw "Docker is not installed or not running"
        }
        Write-Status "Docker version: $DockerVersion"
        
        # Find project root (assuming we're in deploy/ directory)
        $ProjectRoot = Split-Path -Parent $PSScriptRoot
        
        # Check if docker-build.ps1 exists
        $DockerBuildScript = Join-Path $ProjectRoot "docker-build.ps1"
        if (-not (Test-Path $DockerBuildScript)) {
            throw "Docker build script not found at: $DockerBuildScript"
        }
        
        # Build using Docker
        Write-Status "Starting Docker build..."
        Push-Location $ProjectRoot
        try {
            # Build the ISO using docker-build.ps1
            & $DockerBuildScript -- --profile $ProfileName --version $Version --output "/output/$ISOName"
            
            # Check if ISO was created
            $DockerOutput = Join-Path $ProjectRoot "output" $ISOName
            if (Test-Path $DockerOutput) {
                # Move to desired location
                if ($DockerOutput -ne $ISOFullPath) {
                    Move-Item -Path $DockerOutput -Destination $ISOFullPath -Force
                }
                Write-Status "ISO created successfully"
            } else {
                throw "ISO was not created by Docker build"
            }
        } finally {
            Pop-Location
        }
        
    } elseif ($BuildServer) {
        Write-Status "Using remote build server: $BuildServer"
        
        # Build on remote Linux server
        Write-Status "Connecting to build server..."
        
        # Create build command
        $BuildCommand = @"
cd ubuntu-server-unattended-iso &&
./bin/ubuntu-iso \
    --profile $ProfileName \
    --version $Version \
    --output output/$ISOName
"@
        
        # Execute remotely via SSH
        Write-Status "Executing build on remote server..."
        $Result = ssh $BuildServer $BuildCommand
        if ($LASTEXITCODE -ne 0) {
            throw "Remote build failed"
        }
        
        # Download the ISO
        Write-Status "Downloading ISO from build server..."
        scp "${BuildServer}:ubuntu-server-unattended-iso/output/$ISOName" $ISOFullPath
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to download ISO from build server"
        }
        
        Write-Status "ISO downloaded successfully"
        
    } else {
        # Local WSL2 build
        Write-Status "Using local WSL2 build method"
        
        # Check if WSL2 is available
        $WSLVersion = wsl --list --verbose 2>$null
        if (-not $WSLVersion) {
            throw "WSL2 is not installed. Please install WSL2 or use -UseDocker flag"
        }
        
        # Get default WSL distribution
        $DefaultDistro = wsl -l -q | Where-Object { $_ -ne "" } | Select-Object -First 1
        if (-not $DefaultDistro) {
            throw "No WSL distribution found. Please install Ubuntu in WSL2"
        }
        Write-Status "Using WSL distribution: $DefaultDistro"
        
        # Convert Windows path to WSL path
        $ProjectRoot = Split-Path -Parent $PSScriptRoot
        $WSLProjectPath = wsl wslpath -a $ProjectRoot.Replace('\', '/')
        
        # Build in WSL
        Write-Status "Starting WSL build..."
        $BuildCommand = @"
cd '$WSLProjectPath' &&
./bin/ubuntu-iso \
    --profile $ProfileName \
    --version $Version \
    --output output/$ISOName
"@
        
        wsl -d $DefaultDistro bash -c $BuildCommand
        if ($LASTEXITCODE -ne 0) {
            throw "WSL build failed"
        }
        
        # Move ISO to desired location
        $WSLOutput = Join-Path $ProjectRoot "output" $ISOName
        if (Test-Path $WSLOutput) {
            if ($WSLOutput -ne $ISOFullPath) {
                Move-Item -Path $WSLOutput -Destination $ISOFullPath -Force
            }
            Write-Status "ISO created successfully"
        } else {
            throw "ISO was not created by WSL build"
        }
    }
    
    # Verify ISO was created
    if (-not (Test-Path $ISOFullPath)) {
        throw "ISO file was not created"
    }
    
    # Get ISO information
    $ISOInfo = Get-Item $ISOFullPath
    
    Write-Host "`n=== Build Complete ===" @Green
    Write-Host "Role:     $Role"
    Write-Host "Version:  $Version"
    Write-Host "Profile:  $ProfileName"
    Write-Host "ISO:      $ISOFullPath"
    Write-Host "Size:     $([math]::Round($ISOInfo.Length / 1GB, 2)) GB"
    Write-Host "======================" @Green
    
    # Offer to deploy
    Write-Host "`nWould you like to deploy this ISO to a VM? (Y/N)" @Yellow
    $Deploy = Read-Host
    if ($Deploy -eq 'Y' -or $Deploy -eq 'y') {
        $VMName = Read-Host "Enter VM name (e.g., hsc-ctsc-$Role-01)"
        
        $DeployScript = Join-Path $PSScriptRoot "Deploy-VM.ps1"
        if (Test-Path $DeployScript) {
            Write-Status "Deploying VM..."
            & $DeployScript -Name $VMName -ISOPath $ISOFullPath
        } else {
            Write-Warning "Deploy-VM.ps1 not found in $PSScriptRoot"
        }
    }
    
} catch {
    Write-Error $_.Exception.Message
    Write-Host "`nBuild failed. Please check the error message above." @Red
    exit 1
}
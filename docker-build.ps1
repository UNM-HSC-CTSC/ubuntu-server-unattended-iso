# Docker wrapper for Ubuntu ISO Builder - Windows PowerShell version
# This script simplifies running the ISO builder in a Docker container on Windows

param(
    [switch]$Build,
    [switch]$NoCache,
    [switch]$Generate,
    [switch]$Shell,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$IsoArgs
)

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Colors for output (Windows Terminal and PowerShell 7+ support)
if ($Host.UI.SupportsVirtualTerminal) {
    $Green = "`e[32m"
    $Yellow = "`e[33m"
    $Red = "`e[31m"
    $Reset = "`e[0m"
} else {
    $Green = ""
    $Yellow = ""
    $Red = ""
    $Reset = ""
}

# Helper functions
function Write-Info {
    param([string]$Message)
    Write-Host "${Yellow}->${Reset} $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host "${Green}[OK]${Reset} $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "${Red}[ERROR]${Reset} $Message" -ForegroundColor Red
    exit 1
}

# Show usage
function Show-Usage {
    @"
Docker wrapper for Ubuntu ISO Builder - Windows PowerShell

Usage: .\docker-build.ps1 [options] [-- ubuntu-iso-options]

Options:
    -Build          Build/rebuild the Docker image
    -NoCache        Build Docker image without cache
    -Generate       Run the interactive generator
    -Shell          Start a shell in the container
    -Help           Show this help message

Examples:
    # Build an ISO using the base configuration
    .\docker-build.ps1

    # Build with a custom autoinstall.yaml
    .\docker-build.ps1 -- --autoinstall /input/my-config.yaml

    # Run the interactive generator
    .\docker-build.ps1 -Generate

    # Rebuild the Docker image and then build ISO
    .\docker-build.ps1 -Build -- --autoinstall /input/my-config.yaml

    # Start a shell for debugging
    .\docker-build.ps1 -Shell

Volume Mounts:
    .\input   -> /input   (read-only) - Place your autoinstall.yaml files here
    .\output  -> /output  - Generated ISOs will be saved here
    .\cache   -> /cache   - Downloaded Ubuntu ISOs are cached here

Note: Ensure Docker Desktop is running and Linux containers are selected.
"@
    exit 0
}

# Show help if requested
if ($Help) {
    Show-Usage
}

# Check if Docker is available
try {
    docker --version | Out-Null
} catch {
    Write-Error "Docker is not installed or not in PATH. Please install Docker Desktop for Windows."
}

# Check if Docker is running
try {
    docker info 2>&1 | Out-Null
} catch {
    Write-Error "Docker is not running. Please start Docker Desktop."
}

# Change to script directory
Set-Location $ScriptDir

# Create directories if they don't exist
$Directories = @("input", "output", "cache")
foreach ($Dir in $Directories) {
    if (!(Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir | Out-Null
    }
}

# Load .env file if it exists
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

# Build Docker image if requested or if it doesn't exist
$ImageExists = docker image ls --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq "ubuntu-iso-builder:latest" }

if ($Build -or !$ImageExists) {
    Write-Info "Building Docker image..."
    
    $BuildArgs = @("docker-compose", "build")
    if ($NoCache) {
        $BuildArgs += "--no-cache"
    }
    $BuildArgs += "builder"
    
    $BuildProcess = Start-Process -FilePath "docker-compose" -ArgumentList $BuildArgs -NoNewWindow -PassThru -Wait
    if ($BuildProcess.ExitCode -ne 0) {
        Write-Error "Failed to build Docker image"
    }
    Write-Success "Docker image built successfully"
}

# Prepare docker-compose run arguments
$RunArgs = @("run", "--rm")

# Run the appropriate command
if ($Shell) {
    Write-Info "Starting shell in container..."
    $RunArgs += @("builder", "/bin/bash")
    docker-compose @RunArgs
} elseif ($Generate) {
    Write-Info "Starting interactive generator..."
    $RunArgs += "generator"
    docker-compose @RunArgs
} else {
    # Default: run ubuntu-iso with provided arguments
    $RunArgs += "builder"
    
    if ($IsoArgs.Count -eq 0) {
        # No arguments provided, use default
        Write-Info "Building ISO with base configuration..."
        $RunArgs += @("ubuntu-iso", "--autoinstall", "/app/share/ubuntu-base/autoinstall.yaml")
    } else {
        Write-Info "Running ubuntu-iso with custom arguments..."
        $RunArgs += "ubuntu-iso"
        $RunArgs += $IsoArgs
    }
    
    docker-compose @RunArgs
}

# Check if ISO was created
$IsoFiles = Get-ChildItem -Path "output" -Filter "*.iso" -ErrorAction SilentlyContinue

if ($IsoFiles) {
    Write-Success "ISO created successfully!"
    Write-Host ""
    Write-Host "Output files:"
    foreach ($File in $IsoFiles) {
        $Size = [math]::Round($File.Length / 1MB, 2)
        Write-Host "  $($File.Name) (${Size} MB)"
    }
}
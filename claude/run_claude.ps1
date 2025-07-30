
# Get the directory of the script
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Set the path to the .claude directory in the script's directory
$UserClaudeDir = Join-Path $SCRIPT_DIR ".claude"

# Set the project root (one level up from the script directory)
$ProjectRoot = Split-Path $SCRIPT_DIR -Parent

# Interactive prompt function
function Prompt-YesNo($message) {
    $response = Read-Host "$message (y/n)"
    return $response -match "^[Yy]$"
}

if (-Not (Test-Path $UserClaudeDir)) {
    Write-Warning ".claude directory not found in the script directory. Please ensure it exists before running this script."
    exit 1
}

# Check if the Docker image exists
$imageExists = docker images --format "{{.Repository}}" | Where-Object { $_ -eq "claude-code" }
if (-Not $imageExists) {
    Write-Host "Docker image 'claude-code' not found."
    if (Prompt-YesNo "Do you want to build it now?") {
        Write-Host "Building Docker image..."
        & "$SCRIPT_DIR\build.ps1"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to build Docker image."
            exit 1
        }
    } else {
        Write-Host "Cannot run without the Docker image. Please run build.ps1 first."
        exit 1
    }
}

# Run the claude-code container, mounting .claude and the project root as /app
# Check if the container exists
$container = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq "claude-code" }
if ($container) {
    Write-Host "Container 'claude-code' already exists. Starting it..."
    docker start -ai claude-code
} else {
    Write-Host "Running new 'claude-code' container..."
    # Check if host has GitHub CLI config to mount
    $ghConfigMount = ""
    $ghConfigPath = Join-Path $env:USERPROFILE ".config\gh"
    if (Test-Path $ghConfigPath) {
        Write-Host "Found GitHub CLI config, mounting it..."
        $ghConfigMount = "-v `"${ghConfigPath}:/root/.config/gh`""
    }
    
    $dockerCmd = "docker run --name claude-code -it -v `"${UserClaudeDir}:/root/.claude`" -v `"${ProjectRoot}:/app`" $ghConfigMount -w /app claude-code"
    Invoke-Expression $dockerCmd
}

# Get the directory of the script
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Interactive prompt function
function Prompt-YesNo($message) {
    $response = Read-Host "$message (y/n)"
    return $response -match "^[Yy]$"
}

# Check if the container already exists
$containerExists = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq "claude-code" }
if ($containerExists) {
    Write-Host "A container named 'claude-code' already exists."
    if (Prompt-YesNo "Do you want to remove it and build a new one?") {
        Write-Host "Removing existing container..."
        docker rm -f claude-code
    } else {
        Write-Host "Build cancelled."
        exit 0
    }
}

# Build the Docker image for Claude Code
docker build -t claude-code "$SCRIPT_DIR" --file "$SCRIPT_DIR\Dockerfile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed"
    exit $LASTEXITCODE
}

# Set the path to the .claude directory in the script's directory
$UserClaudeDir = Join-Path $SCRIPT_DIR ".claude"

# Set the project root (one level up from the script directory)
$ProjectRoot = Split-Path $SCRIPT_DIR -Parent

# Run the Docker container, mounting .claude and the project root as /app
Write-Host "Select the options and login. Once completed type 'exit' to stop the container."
docker run --name claude-code -v "${UserClaudeDir}:/root/.claude" -v "${ProjectRoot}:/app" -w /app -it claude-code

# Commit the container to save changes
Write-Host "Committing the container to save changes..."
docker commit claude-code claude-code

# Check if the container ran successfully
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker run failed"
    exit $LASTEXITCODE
}

Write-Host "Claude Code Docker image built and container started successfully"

# Optionally, you can push the image to a Docker registry
# docker push claude-code

# Check if the push was successful
# if ($LASTEXITCODE -ne 0) {
#     Write-Host "Docker push failed"
#     exit $LASTEXITCODE
# }
# Write-Host "Docker image

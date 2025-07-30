#!/usr/bin/env fish
set SCRIPT_DIR (dirname (status --current-filename))
set SCRIPT_DIR (cd $SCRIPT_DIR; pwd)

# Interactive prompt function
function prompt_yn
    read -P "$argv[1] (y/n): " -n 1 response
    echo
    test "$response" = "y" -o "$response" = "Y"
end

# Check if the container already exists
if docker ps -a --format '{{.Names}}' | grep -q '^claude-code$'
    echo "A container named 'claude-code' already exists."
    if prompt_yn "Do you want to remove it and build a new one?"
        echo "Removing existing container..."
        docker rm -f claude-code
    else
        echo "Build cancelled."
        exit 0
    end
end

# Build the Docker image for Claude Code
if not docker build -t claude-code $SCRIPT_DIR -f $SCRIPT_DIR/Dockerfile
    echo "Docker build failed"
    exit 1
end

set USER_CLAUDE_DIR "$SCRIPT_DIR/.claude"
set PROJECT_ROOT (dirname $SCRIPT_DIR)

# Run the Docker container
echo "Select the options and login. Once completed type 'exit' to stop the container."
set container (docker ps -a --format '{{.Names}}' | grep '^claude-code$')
if test -n "$container"
    echo "Container 'claude-code' already exists. Starting it..."
    docker start -ai claude-code
else
    echo "Running new 'claude-code' container..."
    docker run --name claude-code -v $USER_CLAUDE_DIR:/root/.claude -v $PROJECT_ROOT:/app -w /app -it claude-code
end

# Commit the container to save changes
echo "Committing the container to save changes..."
docker commit claude-code claude-code

# Check if the container ran successfully
if test $status -ne 0
    echo "Docker run failed"
    exit 1
end

echo "Claude Code Docker image built and container started successfully"

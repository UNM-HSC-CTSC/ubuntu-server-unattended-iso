#!/bin/zsh
SCRIPT_DIR="$(cd "$(dirname ${(%):-%N})" && pwd)"

# Interactive prompt function
prompt_yn() {
    echo -n "$1 (y/n): "
    read -k 1 REPLY
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Check if the container already exists
if docker ps -a --format '{{.Names}}' | grep -q '^claude-code$'; then
  echo "A container named 'claude-code' already exists."
  if prompt_yn "Do you want to remove it and build a new one?"; then
    echo "Removing existing container..."
    docker rm -f claude-code
  else
    echo "Build cancelled."
    exit 0
  fi
fi

# Build the Docker image for Claude Code
if ! docker build -t claude-code "$SCRIPT_DIR" -f "$SCRIPT_DIR/Dockerfile"; then
  echo "Docker build failed"
  exit 1
fi

USER_CLAUDE_DIR="$SCRIPT_DIR/.claude"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Run the Docker container
echo "Select the options and login. Once completed type 'exit' to stop the container."
container=$(docker ps -a --format '{{.Names}}' | grep '^claude-code$')
if [ -n "$container" ]; then
  echo "Container 'claude-code' already exists. Starting it..."
  docker start -ai claude-code
else
  echo "Running new 'claude-code' container..."
  docker run --name claude-code -v "$USER_CLAUDE_DIR:/root/.claude" -v "$PROJECT_ROOT:/app" -w /app -it claude-code
fi

# Commit the container to save changes
echo "Committing the container to save changes..."
docker commit claude-code claude-code

# Check if the container ran successfully
if [ $? -ne 0 ]; then
  echo "Docker run failed"
  exit 1
fi

echo "Claude Code Docker image built and container started successfully"

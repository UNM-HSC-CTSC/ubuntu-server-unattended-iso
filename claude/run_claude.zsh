#!/bin/zsh
SCRIPT_DIR="$(cd "$(dirname ${(%):-%N})" && pwd)"
USER_CLAUDE_DIR="$SCRIPT_DIR/.claude"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Interactive prompt function
prompt_yn() {
    echo -n "$1 (y/n): "
    read -k 1 REPLY
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

if [ ! -d "$USER_CLAUDE_DIR" ]; then
  echo ".claude directory not found in the script directory. Please ensure it exists before running this script."
  exit 1
fi

# Check if the Docker image exists
if ! docker images --format "{{.Repository}}" | grep -q "^claude-code$"; then
  echo "Docker image 'claude-code' not found."
  if prompt_yn "Do you want to build it now?"; then
    echo "Building Docker image..."
    if ! "$SCRIPT_DIR/build.zsh"; then
      echo "Failed to build Docker image."
      exit 1
    fi
  else
    echo "Cannot run without the Docker image. Please run build.zsh first."
    exit 1
  fi
fi

# Check if the container exists
container=$(docker ps -a --format '{{.Names}}' | grep '^claude-code$')
if [ -n "$container" ]; then
  echo "Container 'claude-code' already exists. Starting it..."
  docker start -ai claude-code
else
  echo "Running new 'claude-code' container..."
  # Check if host has GitHub CLI config to mount
  GH_CONFIG_MOUNT=""
  if [ -d "$HOME/.config/gh" ]; then
    echo "Found GitHub CLI config, mounting it..."
    GH_CONFIG_MOUNT="-v $HOME/.config/gh:/root/.config/gh"
  fi
  
  docker run --name claude-code -it \
    -v "$USER_CLAUDE_DIR:/root/.claude" \
    -v "$PROJECT_ROOT:/app" \
    $GH_CONFIG_MOUNT \
    -e PERPLEXITY_API_KEY="${PERPLEXITY_API_KEY:-}" \
    -w /app \
    claude-code
fi

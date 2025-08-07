#!/usr/bin/env fish
set SCRIPT_DIR (dirname (status --current-filename))
set SCRIPT_DIR (cd $SCRIPT_DIR; pwd)
set USER_CLAUDE_DIR "$SCRIPT_DIR/.claude"
set PROJECT_ROOT (dirname $SCRIPT_DIR)

# Interactive prompt function
function prompt_yn
    read -P "$argv[1] (y/n): " -n 1 response
    echo
    test "$response" = "y" -o "$response" = "Y"
end

if not test -d $USER_CLAUDE_DIR
    echo ".claude directory not found in the script directory. Please ensure it exists before running this script."
    exit 1
end

# Check if the Docker image exists
if not docker images --format "{{.Repository}}" | grep -q "^claude-code\$"
    echo "Docker image 'claude-code' not found."
    if prompt_yn "Do you want to build it now?"
        echo "Building Docker image..."
        if not $SCRIPT_DIR/build.fish
            echo "Failed to build Docker image."
            exit 1
        end
    else
        echo "Cannot run without the Docker image. Please run build.fish first."
        exit 1
    end
end

# Check if the container exists
set container (docker ps -a --format '{{.Names}}' | grep '^claude-code$')
if test -n "$container"
    echo "Container 'claude-code' already exists. Starting it..."
    docker start -ai claude-code
else
    echo "Running new 'claude-code' container..."
    # Check if host has GitHub CLI config to mount
    set GH_CONFIG_MOUNT ""
    if test -d "$HOME/.config/gh"
        echo "Found GitHub CLI config, mounting it..."
        set GH_CONFIG_MOUNT "-v $HOME/.config/gh:/root/.config/gh"
    end
    
    docker run --name claude-code -it \
        -v $USER_CLAUDE_DIR:/root/.claude \
        -v $PROJECT_ROOT:/app \
        $GH_CONFIG_MOUNT \
        -e PERPLEXITY_API_KEY="$PERPLEXITY_API_KEY" \
        -w /app \
        claude-code
end

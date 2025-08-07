# Claude Code Docker Container

This directory contains a Docker container setup for Claude Code, providing a consistent environment for the Ubuntu Server Unattended ISO Builder project.

## Features

- Ubuntu 24.04 LTS base image
- Claude Code pre-installed globally
- Essential development tools (git, ripgrep, python3, nodejs)
- ISO manipulation tools (xorriso, genisoimage)
- GitHub CLI (gh) pre-installed
- Persistent Claude configuration via .claude directory
- Project mounted at /app
- **Pre-configured MCP (Model Context Protocol) servers**

## Pre-configured MCP Servers

This container comes with three powerful MCP servers pre-configured:

### 1. Context7
- **Purpose**: Real-time documentation injection for accurate, up-to-date code examples
- **Usage**: Include "use context7" in your prompts to fetch current documentation
- **Example**: "use context7 to show me the latest React hooks documentation"

### 2. Sequential Thinking
- **Purpose**: Structured problem-solving through dynamic thought sequences
- **Usage**: Automatically available for complex problem-solving tasks
- **Benefits**: Helps break down complex problems into manageable steps

### 3. Perplexity
- **Purpose**: Web search capabilities powered by Perplexity AI
- **Usage**: Ask Claude to search the web for current information
- **Setup**: Requires PERPLEXITY_API_KEY environment variable
- **Get API Key**: https://www.perplexity.ai/settings/api

## Prerequisites
- Docker installed and running
- PowerShell (Windows), Bash, Zsh, or Fish
- This directory contains:
  - `build.ps1`, `build.sh`, `build.zsh`, `build.fish` (build scripts)
  - `run_claude.ps1`, `run_claude.sh`, `run_claude.zsh`, `run_claude.fish` (run scripts)
  - `Dockerfile`
  - `.claude/` directory (for persistent config)

## Setup

### Building the Container

Run the appropriate build script for your shell:

```bash
# Bash
./build.sh

# PowerShell
./build.ps1

# Fish
./build.fish

# Zsh
./build.zsh
```

### Running Claude Code

Run the appropriate script for your shell:

```bash
# Bash (with optional Perplexity API key)
export PERPLEXITY_API_KEY=your-api-key  # Optional
./run_claude.sh

# PowerShell
$env:PERPLEXITY_API_KEY = "your-api-key"  # Optional
./run_claude.ps1

# Fish
set -x PERPLEXITY_API_KEY your-api-key  # Optional
./run_claude.fish

# Zsh
export PERPLEXITY_API_KEY=your-api-key  # Optional
./run_claude.zsh
```

## How It Works

1. **Persistent Configuration**: The `.claude` directory in this folder is mounted to `/root/.claude` in the container, preserving your Claude settings between sessions.

2. **Project Access**: The parent directory (ubuntu-server-unattended-iso) is mounted at `/app` in the container.

3. **GitHub Integration**: If you have GitHub CLI configured on your host (~/.config/gh), it will be mounted into the container automatically.

4. **MCP Servers**: Pre-configured in `.claude/.mcp.json` for immediate use.

5. **First Run**: On first run, you'll be prompted to authenticate with GitHub CLI for enhanced features.

## MCP Server Commands

Once in Claude Code, you can use these commands to manage MCP servers:

```bash
# List all configured MCP servers
claude mcp list

# View MCP server details and available tools
claude mcp view <server-name>

# Add additional MCP servers
claude mcp add <name> -- <command>
```

## Using GitHub CLI

After building the container, you can use GitHub CLI inside Claude Code:

```bash
# Authenticate with GitHub
gh auth login

# Check workflow status
gh workflow list
gh run list
gh run view

# Work with pull requests
gh pr list
gh pr create
gh pr review

# Work with issues
gh issue list
gh issue create
```

For the Ubuntu ISO project:
```bash
# Clone the repository
gh repo clone jwylesUNM/ubuntu-server-unattended-iso

# Check workflow runs
gh run list
gh run view --web

# Download artifacts
gh run download

# Create releases
gh release create v1.0.0 --title "Version 1.0.0" --generate-notes
```

## Directory Structure

```
claude/
├── .claude/           # Claude configuration (persisted)
│   └── .mcp.json     # MCP server configurations
├── Dockerfile         # Container definition
├── entrypoint.sh      # Container entry point with checks
├── README.md          # This file
├── build.*            # Build scripts for different shells
└── run_claude.*       # Run scripts for different shells
```

## Notes

- The container runs as root internally (standard for development containers)
- All project files are accessible at /app within the container
- Changes to files in /app are reflected on your host system
- The container is named 'claude-code' for easy management
- Context7 and Sequential Thinking work out of the box
- Perplexity requires an API key but will still load without one

If you encounter any issues, ensure Docker is running and you have the necessary permissions.
# Claude Code Docker Build and Run Instructions

This guide explains how to build and run the Claude Code Docker container with GitHub development tools.

## Features
- Based on Ubuntu 24.04 LTS
- Includes GitHub CLI (`gh`) for workflow monitoring and management
- Python 3 with pip for scripting
- ISO manipulation tools (xorriso, genisoimage)
- Development tools (git, ripgrep, jq, vim)

## Prerequisites
- Docker installed and running
- PowerShell (Windows), Bash, Zsh, or Fish
- This directory contains:
  - `build.ps1`, `build.sh`, `build.zsh`, `build.fish` (build and run scripts)
  - `Dockerfile`
  - `.claude/` directory (for persistent config)

## Steps

### 1. Build and Run the Container
Open your shell in this directory and run the appropriate script:

- PowerShell (Windows):
  ```powershell
  ./build.ps1
  ```
- Bash:
  ```bash
  ./build.sh
  ```
- Zsh:
  ```zsh
  ./build.zsh
  ```
- Fish:
  ```fish
  ./build.fish
  ```

- This will build the Docker image and start a container named `claude-code`.
- The `.claude` directory will be mounted to `/root/.claude` inside the container for persistent configuration.
- The project root will be mounted to `/app` inside the container, so Claude will operate on your project files by default.

### 2. Login to Claude
- When the container starts, follow the prompts in the terminal.
- You will be shown a URL to open in your browser.
- Copy and open the URL in your browser.
- Complete the login process as instructed.

### 3. Exit the Container
- Once you have completed the login and any setup, type `exit` in the container's terminal session and press Enter.
- The script will automatically commit the container state to the `claude-code` image, saving your login session.

### 4. (Optional) Push the Image
- If you want to push the image to a Docker registry, uncomment the relevant lines at the end of `build.ps1` and run the script again.

---

## Using GitHub CLI

After building the new image, you can use GitHub CLI inside Claude Code:

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

---

If you encounter any issues, ensure Docker is running and you have the necessary permissions.

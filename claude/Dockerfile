
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Denver \
    NODE_MAJOR=20

WORKDIR /root

# Install essential tools, Node.js, and GitLab CLI
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        # Basic tools
        curl wget git ripgrep nano ca-certificates gnupg \
        # Build tools
        build-essential \
        # Python for scripts
        python3 python3-pip \
        # ISO manipulation tools for the Ubuntu ISO project
        xorriso genisoimage \
        # Other useful development tools
        jq vim less htop \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install GitLab CLI (glab)
# Note: Use linux_amd64 (lowercase) for the correct download URL
RUN curl -L "https://gitlab.com/gitlab-org/cli/-/releases/v1.64.0/downloads/glab_1.64.0_linux_amd64.deb" -o /tmp/glab.deb \
    && dpkg -i /tmp/glab.deb \
    && rm -f /tmp/glab.deb

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code \
    && mkdir -p /root/.claude

# Verify installations
RUN node --version && npm --version && glab --version

CMD ["claude"]

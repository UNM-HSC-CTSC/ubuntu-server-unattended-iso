# Ubuntu ISO Builder Docker Image
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core tools
    bash \
    curl \
    wget \
    ca-certificates \
    # Python for scripts
    python3 \
    python3-pip \
    python3-yaml \
    # ISO manipulation tools
    genisoimage \
    xorriso \
    isolinux \
    syslinux-utils \
    # Build tools
    make \
    # Git for version info
    git \
    # Additional utilities
    file \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --break-system-packages pyyaml yamllint || true

# Create non-root user for better security (optional, commented out for compatibility)
# RUN useradd -m -s /bin/bash builder
# USER builder

# Set working directory
WORKDIR /app

# Copy project files
COPY . /app/

# Make scripts executable
RUN chmod +x /app/bin/* /app/lib/*.sh /app/tests/*.sh /app/test.sh || true

# Create directories for volumes
RUN mkdir -p /input /output /cache

# Set environment variables
ENV PATH="/app/bin:${PATH}"
ENV CACHE_DIR=/cache
ENV OUTPUT_DIR=/output

# Default command (can be overridden)
CMD ["ubuntu-iso", "--help"]
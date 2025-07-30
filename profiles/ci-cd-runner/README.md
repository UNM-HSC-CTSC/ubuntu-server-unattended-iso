# CI/CD Runner Profile

Multi-platform CI/CD runner optimized for GitHub Actions with support for Docker and Jenkins.

## Installed Components

### Build Tools
- GCC, G++, Make, CMake
- Python 3.x with pip
- Node.js with npm
- Go, Rust, Java (11 & 17)

### CI/CD Runners
- GitHub Actions runner ready
- Docker-in-Docker support
- Jenkins agent capable

### Container Support
- Docker & Docker Compose
- Podman
- Runner user in docker group

## Post-Installation Setup

### GitHub Actions Runner
```bash
cd /opt/actions-runner
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/vX.X.X/actions-runner-linux-x64-X.X.X.tar.gz
tar xzf actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/YOUR-ORG --token YOUR-TOKEN
sudo ./svc.sh install
sudo ./svc.sh start
```

### Jenkins Agent
Configure as SSH agent in Jenkins with credentials for 'runner' user.

## Resource Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum
- **Storage**: 50GB+ for builds

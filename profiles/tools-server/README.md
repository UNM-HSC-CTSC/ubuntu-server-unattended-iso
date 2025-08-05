# Tools Server Profile

This profile creates a development and monitoring tools server using role-based configuration.

## Overview

Creates a tools server with:
- Development environments (multiple languages)
- Container tools (Docker, Kubernetes)
- Monitoring stack (Prometheus, Grafana)
- Infrastructure tools (Terraform, Ansible)
- Log aggregation (ELK stack)

## How It Works

1. **Boot**: Server boots with this ISO
2. **Cloud-Init**: Reads embedded role metadata
3. **Bootstrap**: Contacts config server and identifies as "tools" role
4. **Ansible**: Pulls and executes tools role configuration
5. **Result**: Fully configured development/monitoring server

## Metadata Configuration

The ISO embeds the following metadata:
```yaml
metadata:
  role: tools
  environment: production
  config_server: hsc-ctsc-config.health.unm.edu
```

## Services Installed

### Development Tools
- Languages: Python, Go, Node.js, Java, Ruby
- Editors: Vim, Emacs with configurations
- Build tools: Make, CMake, Maven, Gradle
- Version control: Git with enhanced tools

### Container Tools
- Docker and Docker Compose
- Podman and Buildah
- Kubernetes tools (kubectl, helm)
- Container monitoring

### Monitoring Stack
- Prometheus (metrics collection)
- Grafana (visualization)
- Elasticsearch (log storage)
- Kibana (log analysis)
- Various exporters

### Infrastructure Tools
- Terraform
- Ansible and Ansible Lint
- Packer
- Cloud CLIs (AWS, Azure, GCP)

## Default Access

After deployment:
- **Grafana**: http://server:3000 (admin/admin)
- **Prometheus**: http://server:9090
- **Kibana**: http://server:5601
- **SSH**: sysadmin@server

## Resource Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 16GB minimum
- **Storage**: 100GB minimum (500GB for logs)

## Verification

Check deployment:
```bash
# Check bootstrap
systemctl status bootstrap-role

# Verify services (after Ansible)
docker version
kubectl version --client
systemctl status prometheus
systemctl status grafana-server
```

## Related Documentation

- [Role Definitions](../../docs/ROLE-DEFINITIONS.md#tools-server)
- [Deployment Guide](../../docs/DEPLOYMENT-GUIDE.md)
- [Ansible Tools Role](../../ansible/roles/tools/)
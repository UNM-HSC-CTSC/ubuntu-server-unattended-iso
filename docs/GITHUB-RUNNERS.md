# GitHub Actions Self-Hosted Runners Guide

This comprehensive guide covers deploying, configuring, and managing GitHub Actions self-hosted runners using the Ubuntu Server Unattended ISO Builder system.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Registration](#registration)
- [Management](#management)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Advanced Topics](#advanced-topics)

## Overview

GitHub Actions self-hosted runners provide the compute infrastructure for executing CI/CD workflows in your GitHub Enterprise environment. This implementation offers:

- **Enterprise-Ready**: Production-grade deployment with high availability
- **Secure by Default**: Ephemeral runners, isolation, and comprehensive hardening
- **Scalable**: Support for multiple runners per server and easy horizontal scaling
- **Automated**: Self-configuring with minimal manual intervention
- **Observable**: Built-in monitoring and health checks

### Key Benefits

1. **Control**: Run on your infrastructure with access to internal resources
2. **Performance**: No startup delays, persistent caches, optimized for your workloads
3. **Cost**: No per-minute charges, efficient resource utilization
4. **Compliance**: Data stays within your network, audit trails maintained

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Enterprise                         │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │ Repository  │  │ Organization │  │   Enterprise    │   │
│  │   Runners   │  │   Runners    │  │    Runners      │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬────────┘   │
│         │                 │                    │            │
└─────────┼─────────────────┼────────────────────┼────────────┘
          │                 │                    │
          ▼                 ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                   Runner Infrastructure                      │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Runner Server 1 │  │ Runner Server 2 │  ...             │
│  │                 │  │                 │                   │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │                 │
│  │ │  Runner 1   │ │  │ │  Runner 1   │ │                 │
│  │ │  Runner 2   │ │  │ │  Runner 2   │ │                 │
│  │ │  Runner 3   │ │  │ │  Runner 3   │ │                 │
│  │ │  Runner 4   │ │  │ │  Runner 4   │ │                 │
│  │ └─────────────┘ │  │ └─────────────┘ │                 │
│  │                 │  │                 │                   │
│  │ Docker/Podman   │  │ Docker/Podman   │                  │
│  │ Build Tools     │  │ Build Tools     │                  │
│  │ Monitoring      │  │ Monitoring      │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  Config Server  │  │ Repository Srv  │                  │
│  │  (Ansible/Git)  │  │  (ISOs/Pkgs)    │                  │
│  └─────────────────┘  └─────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

### Runner Lifecycle

1. **Idle**: Runner waits for job assignment
2. **Assigned**: GitHub assigns job to runner
3. **Preparing**: Downloads actions, sets up job container
4. **Running**: Executes workflow steps
5. **Completing**: Uploads artifacts, cleans workspace
6. **Cleanup**: Ephemeral runner terminates; persistent runner returns to idle

## Deployment

### Prerequisites

- GitHub Enterprise Server or Cloud
- Config server deployed and accessible
- Network connectivity to GitHub Enterprise
- DNS resolution configured
- Virtual or physical servers meeting requirements

### System Requirements

**Minimum (per server)**:
- CPU: 2 cores
- RAM: 4GB
- Disk: 100GB
- Network: 100Mbps

**Recommended (per server)**:
- CPU: 8+ cores
- RAM: 16GB+
- Disk: 500GB+ SSD
- Network: 1Gbps

### Quick Deployment

1. **Build the ISO**:
```bash
./bin/ubuntu-iso --role github --output github-runner.iso
```

2. **Deploy VM** (Hyper-V example):
```powershell
.\deploy\Deploy-VM.ps1 -Name "hsc-ctsc-github-01" `
  -ISOPath "github-runner.iso" `
  -Memory 16GB `
  -CPUCount 8 `
  -DiskSize 500GB
```

3. **Wait for Bootstrap**:
- VM boots and gets IP via DHCP
- Contacts config server
- Downloads and runs Ansible playbook
- Installs runner software and dependencies

4. **Verify Deployment**:
```bash
ssh sysadmin@hsc-ctsc-github-01
sudo runner-status
```

### Scaling Out

Deploy additional runner servers as needed:
```bash
# Deploy more servers with same ISO
hsc-ctsc-github-02
hsc-ctsc-github-03
...
```

## Configuration

### Ansible Variables

Key configuration options in `/ansible/roles/github/vars/main.yml`:

```yaml
# GitHub Enterprise settings
github_enterprise_url: "https://github.company.com"
github_enterprise_api_url: "https://github.company.com/api/v3"

# Runner configuration
runner_count: 4                    # Runners per server
runner_labels: "self-hosted,linux,x64,ubuntu-24.04,docker"
runner_ephemeral: true            # Recommended for security
runner_group: "default"           # Runner group assignment

# Features
docker_enabled: true              # Container support
docker_privileged: false          # Privileged containers (security risk)
cache_enabled: true               # Dependency caching

# Resource limits
runner_cpu_limit: "2"             # CPUs per runner
runner_memory_limit: "4G"         # Memory per runner
runner_disk_quota: "50G"          # Disk quota per runner

# Maintenance
cleanup_schedule: "daily"         # Cleanup frequency
auto_update_runners: false        # Automatic updates
log_retention_days: 30            # Log retention
```

### Custom Labels

Add labels to target specific runners:

```yaml
runner_labels: "self-hosted,linux,x64,gpu,cuda"
runner_extra_labels:
  - "team-ml"
  - "high-memory"
```

Use in workflows:
```yaml
jobs:
  build:
    runs-on: [self-hosted, gpu, team-ml]
```

### Runner Groups

Organize runners for access control:

```yaml
runner_group: "production"
```

Configure in GitHub:
1. Enterprise settings → Actions → Runner groups
2. Create groups: production, staging, development
3. Assign repositories/organizations to groups

## Registration

### Interactive Registration

The easiest way to register runners:

```bash
sudo register-runner
```

Follow prompts:
1. Select level (repository/organization/enterprise)
2. Provide GitHub URL
3. Get and enter registration token
4. Configure runner name and labels

### Manual Registration

For automation or specific requirements:

```bash
# Get token from GitHub UI
TOKEN="ABCDEF123456..."

# Register at repository level
sudo -u runner /home/runner/actions-runner/config.sh \
  --url https://github.company.com/org/repo \
  --token $TOKEN \
  --name "hsc-ctsc-runner-prod-01" \
  --labels "production,secure" \
  --ephemeral

# Start service
sudo systemctl start github-runner@1
```

### Bulk Registration

Register all runners on a server:

```bash
#!/bin/bash
TOKEN="YOUR_TOKEN"
URL="https://github.company.com/org"

for i in {1..4}; do
  sudo -u runner$i /home/runner$i/actions-runner/config.sh \
    --url $URL \
    --token $TOKEN \
    --name "runner-$(hostname)-$i" \
    --ephemeral \
    --unattended
  
  sudo systemctl start github-runner@$i
done
```

### Registration Automation

Using HashiCorp Vault (if configured):

```bash
# Store tokens in Vault
vault kv put secret/github-runner/tokens \
  repo_token="..." \
  org_token="..." \
  enterprise_token="..."

# Ansible retrieves and uses tokens automatically
```

## Management

### Daily Operations

**Check Status**:
```bash
sudo runner-status         # Overview of all runners
sudo runner-health-check   # Comprehensive health check
```

**Control Runners**:
```bash
sudo manage-runners start all     # Start all runners
sudo manage-runners stop 2        # Stop runner 2
sudo manage-runners restart all   # Restart all runners
```

**Maintenance Mode**:
```bash
sudo runner-maintenance enable "System updates"
# Perform maintenance
sudo runner-maintenance disable
```

### Updates

**Check for Updates**:
```bash
sudo update-runners check
```

**Apply Updates**:
```bash
sudo runner-maintenance enable "Runner update"
sudo update-runners update
sudo runner-maintenance disable
```

**Rollback if Needed**:
```bash
sudo update-runners rollback
```

### Cleanup

**Manual Cleanup**:
```bash
sudo runner-cleanup       # Clean work directories
sudo docker-cleanup       # Clean Docker resources
```

**Check Cleanup Schedule**:
```bash
crontab -l | grep cleanup
```

### Backup and Recovery

**Backup Configuration**:
```bash
sudo backup-runners
```

**Restore from Backup**:
```bash
cd /var/backups/github-runner
tar xzf latest-backup -C /
# Re-register runners with new tokens
```

## Security

### Security Architecture

1. **Isolation Layers**:
   - User isolation (separate users per runner)
   - Process isolation (systemd security features)
   - Container isolation (Docker/Podman)
   - Network isolation (firewall rules)

2. **Ephemeral Runners**:
   - Clean environment for each job
   - No secret persistence
   - Automatic cleanup
   - Reduced attack surface

3. **Access Controls**:
   - No runner user sudo access
   - Read-only root filesystem
   - Restricted system calls
   - AppArmor profiles

### Security Configuration

**Firewall Rules**:
```bash
# Verify firewall
sudo ufw status

# Rules applied:
- Deny all incoming (except SSH)
- Allow outgoing HTTPS to GitHub
- Block inter-runner communication
```

**AppArmor Status**:
```bash
sudo aa-status | grep github-runner
```

**Audit Logs**:
```bash
# View runner activity
sudo aureport -x --summary
sudo ausearch -k github_runner_work
```

### Security Best Practices

1. **Use Ephemeral Runners**:
   - Always set `runner_ephemeral: true`
   - Prevents cross-job contamination
   - Reduces secrets exposure

2. **Limit Repository Access**:
   - Use runner groups
   - Restrict to private repositories
   - Disable fork pull requests

3. **Regular Updates**:
   - Keep runners updated
   - Apply security patches
   - Update base images

4. **Monitor Activity**:
   - Review audit logs
   - Check for suspicious jobs
   - Monitor resource usage

## Monitoring

### Metrics Collection

Prometheus metrics available at `http://server:9100/metrics`:

```
# Runner status
github_runner_status{runner="prod-01",id="1"} 1
github_runner_busy{runner="prod-01",id="1"} 0

# Resource usage
github_runner_cpu_percent{runner="prod-01",id="1"} 45.2
github_runner_memory_bytes{runner="prod-01",id="1"} 1073741824

# Job metrics
github_runner_jobs_total{runner="prod-01",id="1"} 1523
github_runner_jobs_failed{runner="prod-01",id="1"} 12

# System metrics
github_runner_available 3
github_runner_disk_free_bytes 107374182400
```

### Grafana Dashboard

Import dashboard for visualization:

```json
{
  "dashboard": {
    "title": "GitHub Runners",
    "panels": [
      {
        "title": "Runner Status",
        "targets": [{
          "expr": "github_runner_status"
        }]
      },
      {
        "title": "Job Success Rate",
        "targets": [{
          "expr": "rate(github_runner_jobs_total[5m]) - rate(github_runner_jobs_failed[5m])"
        }]
      }
    ]
  }
}
```

### Alerting Rules

Configure alerts in Prometheus:

```yaml
groups:
  - name: github_runners
    rules:
      - alert: NoRunnersAvailable
        expr: github_runner_available == 0
        for: 5m
        annotations:
          summary: "No GitHub runners available"
          
      - alert: HighFailureRate
        expr: rate(github_runner_jobs_failed[1h]) > 0.1
        annotations:
          summary: "High job failure rate: {{ $value | humanizePercentage }}"
          
      - alert: RunnerDiskFull
        expr: github_runner_disk_free_bytes < 5368709120  # 5GB
        annotations:
          summary: "Runner disk space critical"
```

### Log Analysis

**View Logs**:
```bash
# Service logs
sudo journalctl -u github-runner@1 -f

# Job logs
tail -f /home/runner/actions-runner/_diag/Worker_*.log

# System events
tail -f /var/log/github-runner/events.log
```

**Search Logs**:
```bash
# Find failed jobs
grep "Job completed with result: Failed" /home/runner*/actions-runner/_diag/*.log

# Find specific workflow
grep "workflow-name" /var/log/github-runner/runner-service.log
```

## Troubleshooting

### Common Issues

#### Runner Shows Offline

1. **Check Service**:
```bash
systemctl status github-runner@1
journalctl -u github-runner@1 -n 50
```

2. **Check Connectivity**:
```bash
curl -I https://github.company.com/api/v3
nslookup github.company.com
```

3. **Re-register if Needed**:
```bash
sudo systemctl stop github-runner@1
sudo -u runner /home/runner/actions-runner/config.sh remove --token TOKEN
# Re-run registration
```

#### Jobs Failing

1. **Check Resources**:
```bash
df -h                    # Disk space
free -h                  # Memory
docker system df         # Docker usage
```

2. **Check Logs**:
```bash
# Find specific job
ls -la /home/runner/actions-runner/_diag/
tail -f /home/runner/actions-runner/_diag/Worker_TIMESTAMP.log
```

3. **Test Workflow Locally**:
```bash
# Install act for local testing
docker run --rm -v $PWD:/workspace nektos/act -W .github/workflows/test.yml
```

#### Performance Issues

1. **Check Runner Load**:
```bash
sudo runner-status
htop  # View per-runner CPU/memory
```

2. **Clean Resources**:
```bash
sudo runner-cleanup
sudo docker-cleanup
```

3. **Scale Out**:
- Deploy additional runner servers
- Reduce runner_count if CPU constrained
- Add specific labels for heavy workflows

### Advanced Debugging

**Enable Debug Logging**:
```bash
# Set in workflow
env:
  ACTIONS_RUNNER_DEBUG: true
  ACTIONS_STEP_DEBUG: true
```

**Collect Diagnostics**:
```bash
sudo runner-diagnostics
# Creates /tmp/runner-diagnostics-TIMESTAMP.tar.gz
```

**Network Trace**:
```bash
# Trace GitHub connectivity
sudo tcpdump -i any -w github.pcap host github.company.com
```

## Best Practices

### 1. Deployment

- **Use Role-Based Deployment**: Leverage the ISO builder for consistency
- **Separate Runner Groups**: Production, staging, development
- **Geographic Distribution**: Place runners near developers/resources
- **Capacity Planning**: Monitor usage, scale before hitting limits

### 2. Configuration

- **Ephemeral by Default**: Always use ephemeral runners unless specific need
- **Resource Limits**: Set appropriate CPU/memory/disk limits
- **Custom Labels**: Use descriptive labels for workflow targeting
- **Regular Updates**: Schedule monthly update windows

### 3. Security

- **Least Privilege**: Don't give runners unnecessary access
- **Network Isolation**: Use VLANs/security groups
- **Secrets Management**: Use GitHub secrets, never hardcode
- **Audit Everything**: Enable comprehensive logging

### 4. Operations

- **Monitoring First**: Set up monitoring before issues arise
- **Automate Maintenance**: Use scheduled cleanup and updates
- **Document Procedures**: Create runbooks for common tasks
- **Test Recovery**: Regularly test backup/restore procedures

## Advanced Topics

### Custom Runner Images

Create specialized runner configurations:

```yaml
# ansible/roles/github-ml/vars/main.yml
runner_labels: "self-hosted,linux,gpu,cuda,tensorflow"
additional_packages:
  - nvidia-driver-470
  - cuda-toolkit-11-4
  - python3-tensorflow-gpu
```

### Kubernetes Integration

Deploy runners on Kubernetes with Actions Runner Controller:

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: github-runners
spec:
  replicas: 10
  template:
    spec:
      repository: org/repo
      labels:
        - self-hosted
        - k8s
```

### Hybrid Cloud Runners

Mix self-hosted and GitHub-hosted runners:

```yaml
strategy:
  matrix:
    runner: [ubuntu-latest, self-hosted]
runs-on: ${{ matrix.runner }}
```

### Custom Actions

Create organization-specific actions:

```bash
# On runner server
mkdir -p /opt/actions/org
git clone https://github.company.com/org/custom-actions.git
```

Use in workflows:
```yaml
- uses: ./custom-actions/deploy@v1
```

## Conclusion

GitHub Actions self-hosted runners provide powerful CI/CD capabilities while maintaining control over your infrastructure. This implementation offers enterprise-grade security, scalability, and operational excellence.

For additional help:
- Review logs: `/var/log/github-runner/`
- Check metrics: `http://runner:9100/metrics`
- Run diagnostics: `sudo runner-diagnostics`
- Consult team documentation in config server

Remember: Automate everything, monitor proactively, and maintain security vigilance.
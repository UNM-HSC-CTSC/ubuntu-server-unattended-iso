# GitHub Actions Runner Server Profile

This profile creates a GitHub Actions runner server using role-based configuration with cloud-init metadata.

## Overview

Creates a self-hosted GitHub Actions runner server with:
- Multiple concurrent runners (default: 4)
- Docker support for containerized workflows
- Ephemeral runners for security
- Automated cleanup and maintenance
- Comprehensive monitoring
- Enterprise-ready security hardening

## How It Works

1. **Boot**: Server boots with this ISO
2. **Cloud-Init**: Reads embedded role metadata
3. **Bootstrap**: Contacts config server and identifies as "github" role
4. **Ansible**: Pulls and executes GitHub Actions runner configuration
5. **Result**: Fully configured runner server ready for registration

## Metadata Configuration

The ISO embeds the following metadata:
```yaml
metadata:
  role: github
  environment: production
  config_server: hsc-ctsc-config.health.unm.edu
```

## Network Configuration

- **Initial Hostname**: Set dynamically based on role
- **Final Hostname**: `hsc-ctsc-github-{instance}`
- **IP Assignment**: DHCP from F5 BIG-IP
- **DNS**: Automatically registered

## Default Credentials

- **System User**: `sysadmin` / `ChangeMe123!`
- **Runner User**: `runner` (no direct login)
- **Additional Runners**: `runner2`, `runner3`, etc.

## Post-Deployment

The server will:
1. Contact config server
2. Download Ansible playbooks
3. Install GitHub Actions runner software
4. Configure Docker and build tools
5. Set up monitoring and cleanup jobs
6. Wait for manual runner registration

## Runner Registration

After deployment, register runners with GitHub Enterprise:

```bash
# SSH to server
ssh sysadmin@hsc-ctsc-github-01

# Register a runner interactively
sudo register-runner

# Or register manually
sudo -u runner /home/runner/actions-runner/config.sh \
  --url https://github.enterprise.com/org/repo \
  --token YOUR_REGISTRATION_TOKEN
```

## Verification

Check deployment status:
```bash
# Check bootstrap status
systemctl status bootstrap-role
journalctl -u bootstrap-role

# Check runner status (after Ansible completes)
sudo runner-status

# View runner service logs
sudo journalctl -u github-runner@1 -f

# Check system health
sudo runner-health-check
```

## Management Commands

- `register-runner` - Interactive runner registration wizard
- `runner-status` - Show status of all runners
- `manage-runners {start|stop|restart} [all|#]` - Control runners
- `runner-health-check` - Comprehensive health check
- `runner-cleanup` - Manual cleanup of work directories
- `update-runners` - Check for and apply runner updates
- `runner-maintenance {enable|disable}` - Control maintenance mode

## Monitoring

The server exports Prometheus metrics:
- Runner online/offline status
- Current job execution
- Resource usage (CPU, memory, disk)
- Job success/failure rates
- Docker resource usage

Access metrics at: `http://server:9100/metrics`

## Customization

To use different settings, modify the metadata in the ISO:
```bash
# Build with custom metadata
./bin/ubuntu-iso \
  --role github \
  --metadata "environment=staging" \
  --metadata "config_server=config.example.com"
```

Or customize via Ansible variables:
- `runner_count`: Number of runners (default: 4)
- `runner_labels`: Runner labels
- `runner_ephemeral`: Use ephemeral runners (default: true)
- `docker_enabled`: Enable Docker (default: true)

## Security Features

- Ephemeral runners (clean environment for each job)
- Isolated work directories per runner
- AppArmor profiles for containment
- Automatic cleanup of sensitive data
- Firewall rules (outbound only)
- No sudo access for runner users
- Audit logging enabled

## Troubleshooting

### Bootstrap Fails
```bash
# Check cloud-init metadata
cloud-init query -a

# Check network connectivity
ping hsc-ctsc-config.health.unm.edu

# Run bootstrap manually
sudo /usr/local/bin/bootstrap-role.sh
```

### Runner Won't Start
```bash
# Check configuration
sudo runner-status

# View service logs
sudo journalctl -u github-runner@1 -n 50

# Check for disk space
df -h /home/runner/work
```

### Can't Connect to GitHub
```bash
# Test connectivity
curl -I https://github.enterprise.com/api/v3

# Check proxy settings (if applicable)
echo $HTTP_PROXY $HTTPS_PROXY
```

## Related Documentation

- [Role Definitions](../../docs/ROLE-DEFINITIONS.md#github-server)
- [GitHub Runners Guide](../../docs/GITHUB-RUNNERS.md)
- [Deployment Guide](../../docs/DEPLOYMENT-GUIDE.md)
- [Ansible GitHub Role](../../ansible/roles/github/)
# Repository Server Bootstrap Profile

This profile creates the repository server that stores ISOs, packages, and artifacts for the HSC-CTSC infrastructure.

## Overview

The repository server provides:
- ISO storage and distribution
- Nexus Repository Manager for packages
- Docker registry
- APT package mirror
- API for automated uploads

## Key Features

- **Nexus Repository Manager**: Enterprise-grade artifact management
- **ISO Storage**: Automated ISO upload and versioning
- **Docker Registry**: Private Docker image storage
- **Package Repositories**: Maven, NPM, PyPI, APT mirrors
- **RESTful API**: For CI/CD integration

## Network Configuration

- **Hostname**: `hsc-ctsc-repository` (FQDN: `hsc-ctsc-repository.health.unm.edu`)
- **IP Assignment**: DHCP from F5 BIG-IP
- **Ports**:
  - 22 (SSH)
  - 80 (HTTP - Nexus UI)
  - 443 (HTTPS)
  - 5000 (Docker Registry)
  - 8081 (Nexus Direct)
  - 9100 (Node Exporter)

## Default Credentials

### System
- **Username**: `repoadmin`
- **Password**: `ChangeMe123!` (MUST be changed on first login)

### Nexus
- **Username**: `admin`
- **Password**: `admin123` (MUST be changed on first login)

## Storage Requirements

- **Minimum**: 100GB
- **Recommended**: 500GB+
- **Partitions**:
  - `/boot`: 1GB
  - `/`: 50GB
  - `/var/repository`: Remaining space (artifacts storage)

## Post-Installation Steps

1. **Change Default Passwords**:
   ```bash
   # System password
   ssh repoadmin@hsc-ctsc-repository.health.unm.edu
   passwd
   
   # Nexus admin password
   # Access http://hsc-ctsc-repository.health.unm.edu
   # Login and change password immediately
   ```

2. **Configure Nexus Repositories**:
   - Maven Central proxy
   - NPM registry proxy
   - PyPI proxy
   - Docker Hub proxy
   - Private hosted repositories

3. **Run Ansible Configuration** (if not automatic):
   ```bash
   sudo /usr/local/bin/bootstrap-repository.sh
   ```

4. **Test ISO Upload**:
   ```bash
   curl -X POST http://hsc-ctsc-repository.health.unm.edu/api/upload \
     -F "file=@ubuntu-test.iso" \
     -F "version=1.0.0" \
     -F "role=test"
   ```

## Directory Structure

```
/var/repository/
├── isos/             # ISO images organized by role
│   ├── github/
│   ├── tools/
│   └── artifacts/
├── packages/         # APT package mirror
├── docker/           # Docker registry storage
├── maven/            # Maven artifacts
├── npm/              # NPM packages
└── artifacts/        # Generic artifacts
```

## API Endpoints

### ISO Management
- `POST /api/upload` - Upload new ISO
- `GET /api/isos` - List all ISOs
- `GET /api/isos/{role}/{filename}` - Download specific ISO
- `GET /health` - Health check

### Example Upload
```bash
curl -X POST https://hsc-ctsc-repository.health.unm.edu/api/upload \
  -F "file=@output/ubuntu-github.iso" \
  -F "version=1.2.3" \
  -F "role=github"
```

## Nexus Repository URLs

### Maven
```xml
<repository>
  <id>hsc-nexus</id>
  <url>http://hsc-ctsc-repository.health.unm.edu/repository/maven-public/</url>
</repository>
```

### NPM
```bash
npm config set registry http://hsc-ctsc-repository.health.unm.edu/repository/npm-proxy/
```

### Docker
```bash
docker login hsc-ctsc-repository.health.unm.edu:5000
docker push hsc-ctsc-repository.health.unm.edu:5000/myimage:tag
```

## Storage Management

### Cleanup Policies
Configure in Nexus UI:
- Remove SNAPSHOT versions older than 30 days
- Remove unused Docker layers
- Compact blob stores weekly

### Backup Strategy
```bash
# Backup script runs daily at 3 AM
/usr/local/bin/backup-repository.sh

# Manual backup
sudo tar czf /backup/repository-$(date +%Y%m%d).tar.gz /var/repository/
```

## Security Considerations

1. **Change all default passwords immediately**
2. **Configure SSL certificates for HTTPS**
3. **Set up authentication for all repositories**
4. **Enable Nexus security realms**
5. **Configure cleanup policies to prevent disk exhaustion**
6. **Monitor disk usage regularly**

## Troubleshooting

### Check Service Status
```bash
sudo systemctl status nginx
sudo systemctl status nexus
sudo systemctl status repository-api
sudo systemctl status docker
```

### View Logs
```bash
# Nexus logs
sudo tail -f /opt/sonatype-work/nexus3/log/nexus.log

# API logs
sudo journalctl -u repository-api -f

# Nginx logs
sudo tail -f /var/log/nginx/error.log
```

### Nexus Won't Start
```bash
# Check Java
java -version

# Check disk space
df -h

# Check Nexus process
ps aux | grep nexus

# Manual start for debugging
sudo -u nexus /opt/nexus/nexus/bin/nexus run
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Upload ISO to Repository
  run: |
    curl -X POST https://hsc-ctsc-repository.health.unm.edu/api/upload \
      -H "Authorization: Bearer ${{ secrets.REPO_TOKEN }}" \
      -F "file=@output/ubuntu-${{ matrix.role }}.iso" \
      -F "version=${{ github.sha }}" \
      -F "role=${{ matrix.role }}"
```

## Related Documentation

- [Bootstrap Guide](../../docs/BOOTSTRAP-GUIDE.md)
- [Architecture Overview](../../docs/ARCHITECTURE.md)
- [Deployment Guide](../../docs/DEPLOYMENT-GUIDE.md)
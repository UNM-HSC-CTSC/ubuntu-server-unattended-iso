# Example Web Server Profile

A complete LAMP stack installation with Apache, PHP, MySQL, and security tools.

## Configuration

- **Hostname**: web-server
- **Username**: webadmin
- **Password**: WebAdmin123! (CHANGE IMMEDIATELY!)
- **Network**: Static IP (192.168.1.100/24)
- **Storage**: LVM with separate /var partition
- **Timezone**: America/New_York

## Network Settings

- IP Address: 192.168.1.100/24
- Gateway: 192.168.1.1
- DNS: 8.8.8.8, 8.8.4.4

## Installed Software

### Web Server
- Apache2 with mod_php
- PHP with common extensions (mysql, curl, gd, mbstring, xml, zip)

### Database
- MySQL Server and Client

### Security
- UFW firewall (configured with SSH, HTTP, HTTPS allowed)
- Fail2ban
- Certbot for Let's Encrypt SSL certificates
- Automatic security updates enabled

### Monitoring Tools
- htop (process viewer)
- iotop (I/O monitor)
- vnstat (network statistics)

## Usage

Build an ISO with this profile:

```bash
./build-iso.sh --profile example-web-server
```

## Post-Installation Tasks

1. **Change the default password immediately**:
   ```bash
   passwd webadmin
   ```

2. **Add your SSH key** (update the autoinstall.yaml with your actual key)

3. **Secure MySQL**:
   ```bash
   sudo mysql_secure_installation
   ```

4. **Remove the PHP info file**:
   ```bash
   sudo rm /var/www/html/info.php
   ```

5. **Configure your domain and SSL**:
   ```bash
   sudo certbot --apache -d yourdomain.com
   ```

## Firewall Rules

The following ports are open by default:
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)

## Storage Layout

- `/boot` - 1GB
- `/` - 20GB (root)
- `/var` - 10GB (web files, logs, databases)
- Remaining space in LVM for future expansion
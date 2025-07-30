# Web Server Profile

Complete LAMP/LEMP stack installation with performance optimizations and security hardening.

## Overview

This profile installs a production-ready web server with:
- **Nginx** (primary) and Apache (available)
- **PHP 8.x** with extensive extensions
- **MariaDB** and PostgreSQL
- **Redis** and Memcached
- **SSL/TLS** tools (Certbot)
- **Performance** tools (Varnish, OPcache)
- **Security** hardening

## Configuration

- **Hostname**: web-server
- **Username**: webadmin
- **Password**: WebAdmin123! (MUST BE CHANGED!)
- **Network**: DHCP (static IP recommended for production)
- **Storage**: LVM
- **Primary Web Server**: Nginx
- **PHP**: PHP-FPM with OPcache

## Installed Stacks

### Web Servers
- **Nginx** - Default, high-performance
- **Apache** - Available but disabled

### Programming Languages
- **PHP 8.x** - With 20+ extensions
- **Node.js** - Latest LTS
- **NPM/Yarn** - Package managers

### Databases
- **MariaDB** - MySQL-compatible
- **PostgreSQL** - Advanced RDBMS
- **Redis** - In-memory cache
- **Memcached** - Object caching

### Performance Tools
- **Varnish** - HTTP accelerator
- **OPcache** - PHP bytecode cache
- **APCu** - User cache

### Security Features
- **ModSecurity** - WAF for Apache
- **Fail2ban** - Intrusion prevention
- **UFW** - Firewall (80, 443, 22 open)
- **Certbot** - Let's Encrypt SSL

## Post-Installation Steps

### Immediate Actions
1. **Secure MariaDB**: Run `/root/secure-mysql.sh`
2. **Change passwords**: System and database
3. **Remove test file**: Delete `/var/www/html/info.php`
4. **Configure domain**: Update Nginx server_name

### SSL Configuration
```bash
# For Nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# For Apache (if using)
sudo certbot --apache -d yourdomain.com -d www.yourdomain.com
```

### Database Setup
```bash
# MariaDB
sudo mysql -u root -p
CREATE DATABASE your_app;
CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'strong_password';
GRANT ALL PRIVILEGES ON your_app.* TO 'appuser'@'localhost';
FLUSH PRIVILEGES;

# PostgreSQL
sudo -u postgres createuser --interactive
sudo -u postgres createdb your_app
```

### Performance Tuning

#### PHP-FPM Pool
Edit `/etc/php/8.1/fpm/pool.d/www.conf`:
- Adjust `pm.max_children` based on RAM
- Set `pm.start_servers` to CPU cores
- Configure `pm.max_requests` for memory leaks

#### Nginx Workers
Edit `/etc/nginx/nginx.conf`:
- Set `worker_processes auto;`
- Adjust `worker_connections` based on load

## Directory Structure

```
/var/www/html/          # Web root
/etc/nginx/             # Nginx configuration
/etc/php/8.1/           # PHP configuration
/var/log/nginx/         # Nginx logs
/var/log/mysql/         # Database logs
```

## Firewall Rules

- Port 22: SSH
- Port 80: HTTP
- Port 443: HTTPS

Additional ports can be opened:
```bash
sudo ufw allow 3306  # MySQL (if needed externally)
sudo ufw allow 5432  # PostgreSQL (if needed externally)
```

## Monitoring

### Log Files
- Nginx: `/var/log/nginx/access.log`, `error.log`
- PHP: `/var/log/php8.1-fpm.log`
- MySQL: `/var/log/mysql/error.log`, `slow.log`

### Performance Monitoring
```bash
# Real-time monitoring
htop                    # System resources
iotop                   # Disk I/O
vnstat                  # Network traffic

# Web server status
nginx -t                # Test configuration
systemctl status nginx  # Service status
```

## Switching Web Servers

### To use Apache instead of Nginx:
```bash
sudo systemctl stop nginx
sudo systemctl disable nginx
sudo systemctl enable apache2
sudo systemctl start apache2
sudo a2ensite 000-default
```

## Resource Requirements

- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 20GB minimum
- **CPU**: 2 cores minimum (4 recommended)

## Security Considerations

1. **Change all default passwords**
2. **Configure fail2ban thresholds**
3. **Set up SSL certificates**
4. **Regular security updates**
5. **Configure ModSecurity rules**
6. **Implement rate limiting**

## Building ISO

```bash
./build-iso.sh --profile web-server
```

## Use Cases

- WordPress hosting
- Laravel/Symfony applications
- Node.js applications
- E-commerce sites
- API servers
- Development environments

## Troubleshooting

### 502 Bad Gateway
- Check PHP-FPM: `systemctl status php8.1-fpm`
- Verify socket: `/var/run/php/php8.1-fpm.sock`

### Database Connection Failed
- Check service: `systemctl status mariadb`
- Verify credentials and permissions

### High Load
- Check slow query log
- Review Nginx access logs
- Monitor PHP-FPM status
- Consider enabling Varnish
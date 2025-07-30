# Example Configurations

This directory contains example autoinstall.yaml configurations for different server types. These are provided as references to help you understand the possibilities when creating your own custom configuration.

## Available Examples

### web-server
A complete web server setup with:
- Nginx web server
- PHP-FPM
- MariaDB/PostgreSQL
- SSL/TLS tools (Certbot)
- Performance optimizations

### database-server
A database-focused server with:
- PostgreSQL and MariaDB
- Redis for caching
- Optimized settings for database workloads
- Backup configurations

### container-host
A Docker/Kubernetes ready host with:
- Docker CE and Docker Compose
- Kubernetes tools (kubectl, kubeadm)
- Container-optimized kernel settings

## Using These Examples

1. **Browse for ideas**: Look through these examples to see how different configurations work
2. **Copy snippets**: Take useful parts and incorporate them into your own configuration
3. **Use the generator**: Run `bin/ubuntu-iso-generate` to create your own custom configuration interactively

## Note

These are just examples. The recommended approach is to use the interactive generator to create a configuration tailored to your specific needs.
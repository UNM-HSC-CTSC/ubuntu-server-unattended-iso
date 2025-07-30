# Security Hardened Profile

CIS benchmark-compliant installation with comprehensive security tools and hardening.

## Security Features

- **Disk Encryption**: Full disk encryption with LUKS
- **SSH**: Key-only authentication, hardened configuration
- **Firewall**: UFW with strict rules
- **IDS/IPS**: AIDE, Fail2ban, PSAD
- **Auditing**: auditd with comprehensive rules
- **AppArmor**: Mandatory Access Control
- **Kernel**: Hardened parameters

## Compliance

This profile implements controls for:
- CIS Ubuntu Linux Benchmark
- NIST 800-53
- PCI DSS requirements
- HIPAA technical safeguards

## Post-Installation

1. **Add SSH keys** before first login
2. **Change disk encryption password**
3. **Configure AIDE baseline**: `sudo aideinit`
4. **Review audit logs**: `/var/log/audit/`
5. **Run security scan**: `sudo lynis audit system`

## Default Security Settings

- IPv6 disabled
- Root account locked
- Password complexity enforced
- Automatic security updates
- System call auditing enabled
- File integrity monitoring active

## Access

- SSH only with key authentication
- Fail2ban blocks after 3 failed attempts
- Only 'secadmin' user allowed SSH

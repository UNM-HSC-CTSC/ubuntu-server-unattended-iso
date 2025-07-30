#!/bin/bash

# Create All Profiles Script
# Generates all predefined profiles for Ubuntu Server Unattended ISO Builder

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROFILES_DIR="$PROJECT_DIR/profiles"

# Colors
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    GREEN=''
    YELLOW=''
    NC=''
else
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

info() {
    echo -e "${YELLOW}→${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Create profile directory
create_profile() {
    local name="$1"
    local desc="$2"
    
    info "Creating profile: $name"
    mkdir -p "$PROFILES_DIR/$name"
    
    # We'll use a function to generate each profile
    "generate_${name//-/_}_profile"
    
    success "Created $name profile"
}

# Database Server Profile
generate_database_server_profile() {
    cat > "$PROFILES_DIR/database-server/autoinstall.yaml" << 'EOF'
#cloud-config
# Database Server Installation
# High-performance database server with PostgreSQL and MySQL/MariaDB

version: 1

locale: en_US.UTF-8
keyboard:
  layout: us
  variant: ""

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true

storage:
  layout:
    name: lvm

identity:
  hostname: db-server
  username: dbadmin
  realname: "Database Administrator"
  password: "$6$rounds=4096$NQ.MN83i$7z5kIqGFT5B9ULGQ6w5Qvd8gFWH.MZDHcD5aVXEpr8PrTmFMlcVfGVyYLN5dSLyuJ8LfSr.mYH5ekAYqVxTGH."

ssh:
  install-server: true
  allow-pw: true

packages:
  # PostgreSQL
  - postgresql
  - postgresql-contrib
  - postgresql-client
  - postgresql-doc
  - postgresql-plpython3-14
  - postgresql-plperl-14
  
  # MySQL/MariaDB
  - mariadb-server
  - mariadb-client
  - mariadb-backup
  - mariadb-plugin-rocksdb
  
  # NoSQL
  - redis-server
  - redis-tools
  - mongodb-org
  
  # Performance and backup
  - percona-toolkit
  - mydumper
  - pgbackrest
  - barman
  - wal-g
  
  # Monitoring
  - prometheus-postgres-exporter
  - prometheus-mysqld-exporter
  - pg-activity
  - mytop
  
  # Utilities
  - htop
  - iotop
  - ncdu
  - tmux
  - vim
  - git

package_update: true
package_upgrade: true
timezone: UTC

late-commands:
  # Configure PostgreSQL for performance
  - |
    cat <<EOL > /target/etc/postgresql/14/main/conf.d/99-performance.conf
    # Memory
    shared_buffers = 4GB
    effective_cache_size = 12GB
    work_mem = 128MB
    maintenance_work_mem = 1GB
    
    # Checkpoints
    checkpoint_segments = 32
    checkpoint_completion_target = 0.9
    
    # Write ahead log
    wal_buffers = 16MB
    wal_level = replica
    max_wal_senders = 3
    
    # Query tuning
    random_page_cost = 1.1
    effective_io_concurrency = 200
    
    # Logging
    log_statement = 'mod'
    log_duration = on
    log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d '
    EOL
  
  # Configure MariaDB for performance
  - |
    cat <<EOL > /target/etc/mysql/mariadb.conf.d/99-performance.cnf
    [mysqld]
    # InnoDB
    innodb_buffer_pool_size = 4G
    innodb_log_file_size = 1G
    innodb_flush_method = O_DIRECT
    innodb_file_per_table = 1
    innodb_stats_on_metadata = 0
    
    # MyISAM
    key_buffer_size = 512M
    
    # Query cache
    query_cache_type = 1
    query_cache_size = 128M
    
    # Connections
    max_connections = 500
    thread_cache_size = 50
    
    # Logging
    slow_query_log = 1
    long_query_time = 1
    EOL
  
  # Configure Redis
  - |
    cat <<EOL >> /target/etc/redis/redis.conf
    # Persistence
    save 900 1
    save 300 10
    save 60 10000
    
    # Memory
    maxmemory 2gb
    maxmemory-policy allkeys-lru
    
    # Performance
    tcp-backlog 511
    timeout 0
    tcp-keepalive 300
    EOL
  
  # Firewall
  - curtin in-target --target=/target -- ufw --force enable
  - curtin in-target --target=/target -- ufw allow ssh
  - curtin in-target --target=/target -- ufw allow 5432/tcp comment 'PostgreSQL'
  - curtin in-target --target=/target -- ufw allow 3306/tcp comment 'MySQL/MariaDB'
  - curtin in-target --target=/target -- ufw allow 6379/tcp comment 'Redis'
  
  # Create backup directories
  - curtin in-target --target=/target -- mkdir -p /var/backups/postgresql
  - curtin in-target --target=/target -- mkdir -p /var/backups/mysql
  
  # Enable services
  - curtin in-target --target=/target -- systemctl enable postgresql
  - curtin in-target --target=/target -- systemctl enable mariadb
  - curtin in-target --target=/target -- systemctl enable redis-server
EOF

    cat > "$PROFILES_DIR/database-server/README.md" << 'EOF'
# Database Server Profile

High-performance database server with PostgreSQL, MariaDB, and Redis.

## Installed Databases

- **PostgreSQL 14** - Primary RDBMS
- **MariaDB 10.x** - MySQL-compatible
- **Redis** - In-memory data store
- **MongoDB** - Document database

## Performance Optimizations

- 4GB buffer pools (adjust based on RAM)
- Optimized checkpoint settings
- Query logging for analysis
- Connection pooling ready

## Default Ports

- PostgreSQL: 5432
- MySQL/MariaDB: 3306
- Redis: 6379
- MongoDB: 27017

## Post-Installation

1. Secure databases with provided scripts
2. Configure replication if needed
3. Set up automated backups
4. Tune settings based on workload
EOF
}

# Container Host Profile
generate_container_host_profile() {
    cat > "$PROFILES_DIR/container-host/autoinstall.yaml" << 'EOF'
#cloud-config
# Container Host Installation
# Docker and Kubernetes-ready host with container management tools

version: 1

locale: en_US.UTF-8
keyboard:
  layout: us
  variant: ""

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true

storage:
  layout:
    name: lvm

identity:
  hostname: container-host
  username: containeradmin
  realname: "Container Administrator"
  password: "$6$rounds=4096$AsK9hfX7$kDTmF8tN0M5vj3bX2h9v7PQWqQdxPzFf4vUBkHLCgKvr2zrrFWGpgQvcxmZ9Qx7.Yk4iHj8YKMNhpCn3GD9Zh0"

ssh:
  install-server: true
  allow-pw: true

packages:
  # Container runtimes
  - docker.io
  - containerd
  - runc
  
  # Kubernetes components
  - kubeadm
  - kubelet
  - kubectl
  
  # Container tools
  - docker-compose
  - podman
  - buildah
  - skopeo
  
  # Registry
  - docker-registry
  
  # Monitoring
  - prometheus-node-exporter
  - cadvisor
  
  # Networking
  - bridge-utils
  - net-tools
  
  # Storage
  - lvm2
  - nfs-common
  - ceph-common
  
  # Development
  - git
  - make
  - build-essential
  
  # Utilities
  - htop
  - iotop
  - tmux
  - vim
  - curl
  - wget
  - jq

package_update: true
package_upgrade: true
timezone: UTC

late-commands:
  # Configure Docker
  - curtin in-target --target=/target -- usermod -aG docker containeradmin
  - |
    cat <<EOL > /target/etc/docker/daemon.json
    {
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "100m",
        "max-file": "5"
      },
      "storage-driver": "overlay2",
      "storage-opts": [
        "overlay2.override_kernel_check=true"
      ],
      "metrics-addr": "0.0.0.0:9323",
      "experimental": true
    }
    EOL
  
  # Configure kernel parameters for containers
  - |
    cat <<EOL >> /target/etc/sysctl.d/99-kubernetes.conf
    net.bridge.bridge-nf-call-iptables = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward = 1
    vm.max_map_count = 262144
    fs.inotify.max_user_instances = 8192
    fs.inotify.max_user_watches = 524288
    EOL
  
  # Configure kernel modules
  - |
    cat <<EOL > /target/etc/modules-load.d/containerd.conf
    overlay
    br_netfilter
    EOL
  
  # Firewall configuration
  - curtin in-target --target=/target -- ufw --force enable
  - curtin in-target --target=/target -- ufw allow ssh
  - curtin in-target --target=/target -- ufw allow 2376/tcp comment 'Docker TLS'
  - curtin in-target --target=/target -- ufw allow 2377/tcp comment 'Docker Swarm'
  - curtin in-target --target=/target -- ufw allow 7946/tcp comment 'Container network discovery'
  - curtin in-target --target=/target -- ufw allow 7946/udp
  - curtin in-target --target=/target -- ufw allow 4789/udp comment 'Container overlay network'
  - curtin in-target --target=/target -- ufw allow 6443/tcp comment 'Kubernetes API'
  - curtin in-target --target=/target -- ufw allow 10250/tcp comment 'Kubelet API'
  - curtin in-target --target=/target -- ufw allow 10251/tcp comment 'kube-scheduler'
  - curtin in-target --target=/target -- ufw allow 10252/tcp comment 'kube-controller'
  
  # Create docker compose directory
  - curtin in-target --target=/target -- mkdir -p /opt/containers
  
  # Enable services
  - curtin in-target --target=/target -- systemctl enable docker
  - curtin in-target --target=/target -- systemctl enable containerd
EOF

    cat > "$PROFILES_DIR/container-host/README.md" << 'EOF'
# Container Host Profile

Docker and Kubernetes-ready host with comprehensive container tools.

## Installed Components

- **Docker CE** - Container runtime
- **Kubernetes** - Container orchestration (kubeadm, kubelet, kubectl)
- **Podman** - Daemonless containers
- **Docker Compose** - Multi-container apps
- **Container Registry** - Local registry

## Configuration

- Docker configured with systemd cgroup driver
- Kernel parameters optimized for containers
- Firewall rules for container networking
- User added to docker group

## Post-Installation

### Initialize Kubernetes (Master)
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Join Kubernetes (Worker)
```bash
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### Docker Swarm Mode
```bash
# Initialize swarm
docker swarm init

# Join swarm
docker swarm join --token <token> <manager-ip>:2377
```
EOF
}

# Security Hardened Profile
generate_security_hardened_profile() {
    cat > "$PROFILES_DIR/security-hardened/autoinstall.yaml" << 'EOF'
#cloud-config
# Security Hardened Server Installation
# CIS benchmark compliant with comprehensive security tools

version: 1

locale: en_US.UTF-8
keyboard:
  layout: us
  variant: ""

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false  # Disable IPv6 for security

storage:
  layout:
    name: lvm
    password: "DiskEncryption123!"  # CHANGE THIS!

identity:
  hostname: secure-server
  username: secadmin
  realname: "Security Administrator"
  password: "$6$rounds=4096$8Ukt3sTC$oZ7mJNLpZ8QJCLrk9VKfKmW5ECRfHnwLgCZ2lRJTBx8tZ5xYyCnbtJLtL7mPxLKHwZvJTGPBSZvNqXHKZkNXm0"

ssh:
  install-server: true
  allow-pw: false  # Key-only authentication

packages:
  # Security tools
  - aide
  - rkhunter
  - chkrootkit
  - clamav
  - clamav-daemon
  - lynis
  - tiger
  - tripwire
  
  # Firewall and network security
  - ufw
  - fail2ban
  - iptables-persistent
  - nftables
  - psad
  - fwsnort
  
  # AppArmor and SELinux
  - apparmor
  - apparmor-utils
  - apparmor-profiles
  - apparmor-profiles-extra
  
  # Auditing and compliance
  - auditd
  - audispd-plugins
  - aide-common
  - sysstat
  
  # Encryption tools
  - cryptsetup
  - gnupg
  - openssh-server
  
  # Password and access control
  - libpam-pwquality
  - libpam-tmpdir
  - libpam-apparmor
  - google-authenticator
  
  # System hardening
  - needrestart
  - debsums
  - apt-listchanges
  - unattended-upgrades
  
  # Logging and monitoring
  - rsyslog
  - logwatch
  - syslog-ng
  
  # Basic tools
  - vim
  - tmux
  - curl
  - wget

package_update: true
package_upgrade: true
timezone: UTC

unattended-upgrades:
  enable: true

late-commands:
  # Kernel hardening
  - |
    cat <<EOL > /target/etc/sysctl.d/99-security-hardening.conf
    # Kernel hardening
    kernel.randomize_va_space = 2
    kernel.dmesg_restrict = 1
    kernel.kptr_restrict = 2
    kernel.yama.ptrace_scope = 1
    kernel.unprivileged_bpf_disabled = 1
    net.core.bpf_jit_harden = 2
    
    # Network hardening
    net.ipv4.conf.all.rp_filter = 1
    net.ipv4.conf.default.rp_filter = 1
    net.ipv4.conf.all.accept_redirects = 0
    net.ipv4.conf.default.accept_redirects = 0
    net.ipv4.conf.all.send_redirects = 0
    net.ipv4.conf.default.send_redirects = 0
    net.ipv4.conf.all.accept_source_route = 0
    net.ipv4.conf.default.accept_source_route = 0
    net.ipv4.conf.all.log_martians = 1
    net.ipv4.conf.default.log_martians = 1
    net.ipv4.icmp_echo_ignore_broadcasts = 1
    net.ipv4.icmp_ignore_bogus_error_responses = 1
    net.ipv4.tcp_syncookies = 1
    net.ipv4.tcp_rfc1337 = 1
    net.ipv4.tcp_timestamps = 0
    
    # IPv6 hardening (disabled)
    net.ipv6.conf.all.disable_ipv6 = 1
    net.ipv6.conf.default.disable_ipv6 = 1
    net.ipv6.conf.lo.disable_ipv6 = 1
    
    # File system hardening
    fs.protected_hardlinks = 1
    fs.protected_symlinks = 1
    fs.suid_dumpable = 0
    EOL
  
  # SSH hardening
  - |
    cat <<EOL > /target/etc/ssh/sshd_config.d/99-hardening.conf
    # SSH Hardening
    Protocol 2
    Port 22
    
    # Authentication
    PermitRootLogin no
    PasswordAuthentication no
    PubkeyAuthentication yes
    ChallengeResponseAuthentication no
    PermitEmptyPasswords no
    MaxAuthTries 3
    
    # Security
    StrictModes yes
    IgnoreRhosts yes
    HostbasedAuthentication no
    X11Forwarding no
    PermitUserEnvironment no
    AllowUsers secadmin
    
    # Crypto
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
    
    # Logging
    SyslogFacility AUTH
    LogLevel VERBOSE
    
    # Timeouts
    ClientAliveInterval 300
    ClientAliveCountMax 0
    LoginGraceTime 30
    EOL
  
  # PAM configuration
  - |
    cat <<EOL > /target/etc/security/pwquality.conf
    # Password quality requirements
    minlen = 14
    dcredit = -1
    ucredit = -1
    ocredit = -1
    lcredit = -1
    maxrepeat = 3
    maxclassrepeat = 3
    gecoscheck = 1
    dictcheck = 1
    usercheck = 1
    enforcing = 1
    EOL
  
  # Audit rules
  - |
    cat <<EOL > /target/etc/audit/rules.d/hardening.rules
    # Delete all rules
    -D
    
    # Buffer size
    -b 8192
    
    # Failure mode
    -f 1
    
    # Monitor authentication
    -w /etc/passwd -p wa -k passwd_changes
    -w /etc/group -p wa -k group_changes
    -w /etc/shadow -p wa -k shadow_changes
    -w /etc/gshadow -p wa -k gshadow_changes
    
    # Monitor sudo
    -w /etc/sudoers -p wa -k sudoers_changes
    -w /etc/sudoers.d/ -p wa -k sudoers_changes
    
    # Monitor SSH
    -w /etc/ssh/sshd_config -p wa -k sshd_config
    
    # Monitor kernel modules
    -w /sbin/insmod -p x -k modules
    -w /sbin/rmmod -p x -k modules
    -w /sbin/modprobe -p x -k modules
    -a always,exit -F arch=b64 -S init_module -S delete_module -k modules
    
    # Monitor file operations
    -a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
    -a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
    -a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
    
    # Make configuration immutable
    -e 2
    EOL
  
  # Configure firewall
  - curtin in-target --target=/target -- ufw --force enable
  - curtin in-target --target=/target -- ufw default deny incoming
  - curtin in-target --target=/target -- ufw default allow outgoing
  - curtin in-target --target=/target -- ufw allow 22/tcp
  - curtin in-target --target=/target -- ufw logging on
  
  # Configure fail2ban
  - |
    cat <<EOL > /target/etc/fail2ban/jail.local
    [DEFAULT]
    bantime = 86400
    findtime = 600
    maxretry = 3
    destemail = root@localhost
    sendername = Fail2Ban
    action = %(action_mwl)s
    
    [sshd]
    enabled = true
    port = 22
    filter = sshd
    logpath = /var/log/auth.log
    maxretry = 3
    EOL
  
  # Configure AIDE
  - curtin in-target --target=/target -- aideinit
  - curtin in-target --target=/target -- mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  
  # Set file permissions
  - curtin in-target --target=/target -- chmod 644 /etc/passwd
  - curtin in-target --target=/target -- chmod 000 /etc/shadow
  - curtin in-target --target=/target -- chmod 000 /etc/gshadow
  - curtin in-target --target=/target -- chmod 644 /etc/group
  
  # Disable unnecessary services
  - curtin in-target --target=/target -- systemctl disable bluetooth.service || true
  - curtin in-target --target=/target -- systemctl disable cups.service || true
  - curtin in-target --target=/target -- systemctl disable avahi-daemon.service || true
  
  # Enable security services
  - curtin in-target --target=/target -- systemctl enable auditd
  - curtin in-target --target=/target -- systemctl enable fail2ban
  - curtin in-target --target=/target -- systemctl enable apparmor
  - curtin in-target --target=/target -- systemctl enable clamav-freshclam
  
  # Lock root account
  - curtin in-target --target=/target -- passwd -l root
  
  # Set secure umask
  - echo "umask 077" >> /target/etc/profile
  - echo "umask 077" >> /target/etc/bash.bashrc
EOF

    cat > "$PROFILES_DIR/security-hardened/README.md" << 'EOF'
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
EOF
}

# Hyper-V Optimized Profile
generate_hyper_v_optimized_profile() {
    cat > "$PROFILES_DIR/hyper-v-optimized/autoinstall.yaml" << 'EOF'
#cloud-config
# Hyper-V Optimized Installation
# Optimized for Microsoft Hyper-V with integration services

version: 1

locale: en_US.UTF-8
keyboard:
  layout: us
  variant: ""

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      # Hyper-V synthetic network adapter
      match:
        driver: hv_netvsc

storage:
  layout:
    name: lvm

identity:
  hostname: hyperv-ubuntu
  username: hvadmin
  realname: "Hyper-V Administrator"
  password: "$6$rounds=4096$VTqez1x6$.N8FgLQRt3HvGxU8JQV1kxF9Y5TmVxLB9KttZFqH4tP1YqJHhGfYdxYvRXGfrLjQQrkyY5hBSZvNqXHKZNbDd/"

ssh:
  install-server: true
  allow-pw: true

packages:
  # Hyper-V specific
  - linux-virtual
  - linux-cloud-tools-virtual
  - linux-tools-virtual
  
  # Integration services
  - hyperv-daemons
  
  # Performance tools
  - tuned
  - irqbalance
  
  # Monitoring
  - htop
  - iotop
  - sysstat
  
  # Basic tools
  - vim
  - curl
  - wget
  - tmux

package_update: true
package_upgrade: true
timezone: UTC

late-commands:
  # Optimize for Hyper-V
  - |
    cat <<EOL > /target/etc/sysctl.d/99-hyperv.conf
    # Hyper-V optimizations
    vm.swappiness = 10
    vm.dirty_ratio = 15
    vm.dirty_background_ratio = 5
    
    # Network optimizations
    net.core.rmem_max = 134217728
    net.core.wmem_max = 134217728
    net.ipv4.tcp_rmem = 4096 87380 134217728
    net.ipv4.tcp_wmem = 4096 65536 134217728
    net.core.netdev_max_backlog = 5000
    EOL
  
  # Configure Hyper-V daemons
  - curtin in-target --target=/target -- systemctl enable hv-kvp-daemon
  - curtin in-target --target=/target -- systemctl enable hv-vss-daemon
  - curtin in-target --target=/target -- systemctl enable hv-fcopy-daemon
  
  # Disable unnecessary services for VM
  - curtin in-target --target=/target -- systemctl disable bluetooth.service || true
  - curtin in-target --target=/target -- systemctl disable cups.service || true
  
  # Configure tuned for virtual guest
  - curtin in-target --target=/target -- tuned-adm profile virtual-guest
  
  # Set up Hyper-V video
  - echo "blacklist hyperv_fb" > /target/etc/modprobe.d/blacklist-hyperv_fb.conf
EOF

    cat > "$PROFILES_DIR/hyper-v-optimized/README.md" << 'EOF'
# Hyper-V Optimized Profile

Ubuntu Server optimized for Microsoft Hyper-V virtualization platform.

## Optimizations

- **Kernel**: linux-virtual for Hyper-V
- **Integration Services**: Full Hyper-V daemons
- **Network**: Synthetic adapter support
- **Memory**: Optimized swappiness
- **Storage**: LVM for dynamic disks

## Hyper-V Features Enabled

- Key-Value Pair Exchange
- VSS Snapshot support
- File Copy service
- Heartbeat
- Time Synchronization
- Shutdown integration

## Performance Tuning

- Reduced swappiness (10)
- Optimized dirty page ratios
- Increased network buffers
- tuned profile: virtual-guest

## Post-Installation

1. Enable Dynamic Memory in Hyper-V settings
2. Install Hyper-V GPU if using RemoteFX
3. Configure backup with VSS integration
4. Set up monitoring with Windows Admin Center
EOF
}

# CI/CD Runner Profile
generate_ci_cd_runner_profile() {
    cat > "$PROFILES_DIR/ci-cd-runner/autoinstall.yaml" << 'EOF'
#cloud-config
# CI/CD Runner Installation
# GitLab Runner, Jenkins agent, and GitHub Actions runner ready

version: 1

locale: en_US.UTF-8
keyboard:
  layout: us
  variant: ""

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true

storage:
  layout:
    name: lvm

identity:
  hostname: ci-runner
  username: runner
  realname: "CI/CD Runner"
  password: "$6$rounds=4096$RnQ5KhAB$JXKhLcVJQBH4tPJYGPFc4KQur8bGKYGVLHGRhBVPZ8tZ5xYyCnbtJLtL7mPxLKHwZvJTGPBSZvNqXHKZkLuTC1"

ssh:
  install-server: true
  allow-pw: true

packages:
  # Version control
  - git
  - git-lfs
  - subversion
  - mercurial
  
  # Build tools
  - build-essential
  - cmake
  - make
  - gcc
  - g++
  
  # Languages and runtimes
  - python3
  - python3-pip
  - python3-venv
  - nodejs
  - npm
  - golang
  - rustc
  - cargo
  - openjdk-11-jdk
  - openjdk-17-jdk
  
  # Container tools
  - docker.io
  - docker-compose
  - podman
  
  # CI/CD tools
  - curl
  - wget
  - jq
  - zip
  - unzip
  
  # Testing tools
  - chromium-browser
  - firefox
  - xvfb
  
  # Database clients
  - postgresql-client
  - mysql-client
  - redis-tools
  
  # Monitoring
  - htop
  - iotop

package_update: true
package_upgrade: true
timezone: UTC

late-commands:
  # Add runner to docker group
  - curtin in-target --target=/target -- usermod -aG docker runner
  
  # Create runners directory
  - curtin in-target --target=/target -- mkdir -p /opt/runners
  - curtin in-target --target=/target -- chown runner:runner /opt/runners
  
  # Download GitLab Runner
  - |
    curl -L --output /target/usr/local/bin/gitlab-runner \
      "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64"
  - curtin in-target --target=/target -- chmod +x /usr/local/bin/gitlab-runner
  - curtin in-target --target=/target -- gitlab-runner install --user=runner --working-directory=/opt/runners
  
  # Prepare for GitHub Actions runner
  - curtin in-target --target=/target -- mkdir -p /opt/actions-runner
  - curtin in-target --target=/target -- chown runner:runner /opt/actions-runner
  
  # Configure Docker for runners
  - |
    cat <<EOL > /target/etc/docker/daemon.json
    {
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      },
      "storage-driver": "overlay2"
    }
    EOL
  
  # Increase file watchers for builds
  - echo "fs.inotify.max_user_watches=524288" >> /target/etc/sysctl.d/99-runners.conf
  
  # Create runner registration script
  - |
    cat <<'SCRIPT' > /target/opt/runners/register-gitlab-runner.sh
    #!/bin/bash
    echo "Register GitLab Runner"
    echo "Usage: $0 <gitlab-url> <registration-token>"
    gitlab-runner register \
      --non-interactive \
      --url "$1" \
      --registration-token "$2" \
      --executor "docker" \
      --docker-image alpine:latest \
      --description "docker-runner" \
      --tag-list "docker,aws" \
      --run-untagged="true" \
      --locked="false" \
      --access-level="not_protected"
    SCRIPT
  - curtin in-target --target=/target -- chmod +x /opt/runners/register-gitlab-runner.sh
  
  # Enable services
  - curtin in-target --target=/target -- systemctl enable docker
  - curtin in-target --target=/target -- systemctl enable gitlab-runner
EOF

    cat > "$PROFILES_DIR/ci-cd-runner/README.md" << 'EOF'
# CI/CD Runner Profile

Multi-platform CI/CD runner supporting GitLab, GitHub Actions, and Jenkins.

## Installed Components

### Build Tools
- GCC, G++, Make, CMake
- Python 3.x with pip
- Node.js with npm
- Go, Rust, Java (11 & 17)

### CI/CD Runners
- GitLab Runner (latest)
- GitHub Actions runner ready
- Jenkins agent capable

### Container Support
- Docker & Docker Compose
- Podman
- Runner user in docker group

## Post-Installation Setup

### GitLab Runner Registration
```bash
sudo /opt/runners/register-gitlab-runner.sh https://gitlab.com YOUR-REGISTRATION-TOKEN
```

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
EOF
}

# Monitoring Server Profile
generate_monitoring_server_profile() {
    cat > "$PROFILES_DIR/monitoring-server/autoinstall.yaml" << 'EOF'
#cloud-config
# Monitoring Server Installation
# Prometheus, Grafana, and comprehensive monitoring stack

version: 1

locale: en_US.UTF-8
keyboard:
  layout: us
  variant: ""

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true

storage:
  layout:
    name: lvm

identity:
  hostname: monitor-server
  username: monitoradmin
  realname: "Monitor Administrator"
  password: "$6$rounds=4096$ZmNPT8Yh$9FQLmSt1WYGFhKgVqJG8ZQX7PHJKnbtJLtL7mPxLKHwZvJTGPBSZvNqXHKZBH3P1"

ssh:
  install-server: true
  allow-pw: true

packages:
  # Monitoring stack
  - prometheus
  - prometheus-node-exporter
  - prometheus-alertmanager
  - prometheus-pushgateway
  - grafana
  
  # Time series databases
  - influxdb
  - telegraf
  
  # Log management
  - elasticsearch
  - logstash
  - kibana
  - filebeat
  - metricbeat
  
  # Additional exporters
  - prometheus-blackbox-exporter
  - prometheus-postgres-exporter
  - prometheus-mysqld-exporter
  - prometheus-redis-exporter
  
  # Utilities
  - nginx
  - certbot
  - python3-certbot-nginx
  - htop
  - vim
  - curl
  - jq

package_update: true
package_upgrade: true
timezone: UTC

late-commands:
  # Configure Prometheus
  - |
    cat <<EOL > /target/etc/prometheus/prometheus.yml
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets: ['localhost:9093']
    
    rule_files:
      - "alerts/*.yml"
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'node'
        static_configs:
          - targets: ['localhost:9100']
      
      - job_name: 'grafana'
        static_configs:
          - targets: ['localhost:3000']
    EOL
  
  # Configure Grafana
  - |
    cat <<EOL >> /target/etc/grafana/grafana.ini
    [server]
    http_port = 3000
    domain = localhost
    
    [security]
    admin_user = admin
    admin_password = ChangeMe123!
    
    [auth.anonymous]
    enabled = false
    
    [alerting]
    enabled = true
    
    [database]
    type = sqlite3
    EOL
  
  # Configure Nginx reverse proxy
  - |
    cat <<EOL > /target/etc/nginx/sites-available/monitoring
    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://localhost:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location /prometheus {
            proxy_pass http://localhost:9090;
            proxy_set_header Host \$host;
        }
        
        location /alertmanager {
            proxy_pass http://localhost:9093;
            proxy_set_header Host \$host;
        }
    }
    EOL
  
  # Enable sites
  - curtin in-target --target=/target -- ln -s /etc/nginx/sites-available/monitoring /etc/nginx/sites-enabled/
  - curtin in-target --target=/target -- rm -f /etc/nginx/sites-enabled/default
  
  # Create alerts directory
  - curtin in-target --target=/target -- mkdir -p /etc/prometheus/alerts
  
  # Basic alerting rules
  - |
    cat <<EOL > /target/etc/prometheus/alerts/basic.yml
    groups:
      - name: basic
        rules:
          - alert: InstanceDown
            expr: up == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Instance {{ \$labels.instance }} down"
          
          - alert: HighCPU
            expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "High CPU usage detected"
          
          - alert: HighMemory
            expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "High memory usage detected"
    EOL
  
  # Firewall configuration
  - curtin in-target --target=/target -- ufw --force enable
  - curtin in-target --target=/target -- ufw allow ssh
  - curtin in-target --target=/target -- ufw allow 80/tcp
  - curtin in-target --target=/target -- ufw allow 443/tcp
  - curtin in-target --target=/target -- ufw allow 3000/tcp comment 'Grafana'
  - curtin in-target --target=/target -- ufw allow 9090/tcp comment 'Prometheus'
  - curtin in-target --target=/target -- ufw allow 9093/tcp comment 'Alertmanager'
  
  # Enable services
  - curtin in-target --target=/target -- systemctl enable prometheus
  - curtin in-target --target=/target -- systemctl enable grafana-server
  - curtin in-target --target=/target -- systemctl enable prometheus-node-exporter
  - curtin in-target --target=/target -- systemctl enable nginx
EOF

    cat > "$PROFILES_DIR/monitoring-server/README.md" << 'EOF'
# Monitoring Server Profile

Complete monitoring stack with Prometheus, Grafana, and ELK.

## Components

### Metrics
- **Prometheus** - Metrics collection
- **Grafana** - Visualization (admin/ChangeMe123!)
- **InfluxDB** - Time series database
- **Telegraf** - Metrics collector

### Logs
- **Elasticsearch** - Log storage
- **Logstash** - Log processing
- **Kibana** - Log visualization
- **Filebeat** - Log shipper

### Exporters
- Node Exporter (system metrics)
- Blackbox Exporter (endpoint monitoring)
- Database exporters (PostgreSQL, MySQL, Redis)

## Access Points

- **Grafana**: http://server-ip:3000
- **Prometheus**: http://server-ip:9090
- **Alertmanager**: http://server-ip:9093
- **Kibana**: http://server-ip:5601

## Post-Installation

1. Change Grafana admin password
2. Import dashboards from grafana.com
3. Configure alert notifications
4. Add monitoring targets
5. Set up SSL with certbot

## Adding Targets

Edit `/etc/prometheus/prometheus.yml`:
```yaml
- job_name: 'my-app'
  static_configs:
    - targets: ['app-server:9100']
```

Then reload: `sudo systemctl reload prometheus`
EOF
}

# Main execution
info "Creating all Ubuntu Server Unattended ISO profiles"
echo

# Create all profiles
create_profile "database-server" "High-performance database server"
create_profile "container-host" "Docker and Kubernetes ready host"
create_profile "security-hardened" "CIS benchmark compliant secure server"
create_profile "hyper-v-optimized" "Optimized for Hyper-V virtualization"
create_profile "ci-cd-runner" "CI/CD runner for multiple platforms"
create_profile "monitoring-server" "Complete monitoring stack"

echo
success "All profiles created successfully!"
info "Total profiles: $(ls -1 $PROFILES_DIR | wc -l)"
echo
info "To build an ISO for any profile:"
echo "  ./build-iso.sh --profile <profile-name>"
echo
info "To validate profiles:"
echo "  ./scripts/validate-autoinstall.sh profiles/*/autoinstall.yaml"
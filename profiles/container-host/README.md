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

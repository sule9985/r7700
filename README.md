# r7700 - Proxmox Kubernetes Infrastructure

Infrastructure-as-Code for a high-availability Kubernetes cluster on Proxmox, with Rancher management.

## Project Overview

This project provisions and configures a complete Kubernetes infrastructure on Proxmox using Terraform and Ansible:

- **8 VMs total**: 1 load balancer, 3 control planes, 3 workers, 1 jump server
- **1 Rancher server**: K3s-based management platform
- **High Availability**: 3 control plane nodes behind nginx load balancer
- **Network**: 192.168.100.0/24 subnet

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Proxmox Host (192.168.100.4)                                    │
│                                                                  │
│  ┌──────────────┐         ┌─────────────────────────────────┐  │
│  │ Jump Server  │────────▶│ K8s Cluster (HA)                │  │
│  │ .19          │         │  ┌──────────────┐               │  │
│  └──────────────┘         │  │ Load Balancer│               │  │
│                           │  │ .10 (nginx)  │               │  │
│  ┌──────────────┐         │  └──────┬───────┘               │  │
│  │ Rancher      │         │         │                        │  │
│  │ .20 (K3s)    │◀────────┤  ┌──────▼───────────────────┐   │  │
│  └──────────────┘         │  │ Control Planes (3)       │   │  │
│                           │  │ .11, .12, .13 (kubeadm)  │   │  │
│                           │  └──────┬───────────────────┘   │  │
│                           │         │                        │  │
│                           │  ┌──────▼───────────────────┐   │  │
│                           │  │ Workers (3)              │   │  │
│                           │  │ .14, .15, .16            │   │  │
│                           │  └──────────────────────────┘   │  │
│                           └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### r77-tf/ - Terraform Infrastructure

Provisions VMs and LXC containers on Proxmox using the **bpg/proxmox** provider.

**Components:**
- `modules/vm/` - Reusable VM module (QEMU with cloud-init)
- `modules/lxc/` - Reusable LXC container module
- `components/k8s-cluster/` - Main K8s cluster (7 VMs)
- `components/k8s-jump/` - Jump server (1 VM)
- `components/k8s-rancher/` - Rancher management server (1 VM)

[📖 Terraform Documentation](r77-tf/README.md)

### r77-ansible/ - Configuration Management

Configures VMs using Ansible playbooks.

**Playbooks:**
- `setup-jump.yml` - Install kubectl and tools on jump server
- `setup-lb.yml` - Configure nginx load balancer
- `setup-k8s.yml` - Prepare K8s nodes (containerd, kubeadm, kubelet)
- `rancher-setup.yml` - Install K3s + Rancher
- `reset-k8s.yml` - Destroy cluster (for starting over)

[📖 Ansible Documentation](r77-ansible/README.md)

## Quick Start

### Prerequisites

- Proxmox VE 8.x
- Debian 13 template (VMID 998 or 999)
- SSH key pair at `r77-tf/keys/vm-deb13.pub`
- Proxmox API token with VM management permissions

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd r7700

# Configure Proxmox credentials (use environment variables)
export TF_VAR_proxmox_api_url="https://192.168.100.4:8006"
export TF_VAR_proxmox_api_token_id="user@pam!terraform=secret"
export TF_VAR_proxmox_tls_insecure=true
```

### 2. Deploy Infrastructure

```bash
# Deploy K8s cluster VMs
cd r77-tf/components/k8s-cluster
terraform init
terraform apply

# Deploy jump server
cd ../k8s-jump
terraform init
terraform apply

# Deploy Rancher server
cd ../k8s-rancher
terraform init
terraform apply
```

### 3. Configure with Ansible

```bash
cd ../../../r77-ansible

# Test connectivity
ansible all -m ping

# Setup all components
ansible-playbook setup-jump.yml
ansible-playbook setup-lb.yml
ansible-playbook setup-k8s.yml
ansible-playbook rancher-setup.yml
ansible-playbook install-nginx-ingress.yml
```

### 4. Initialize Kubernetes Cluster

```bash
# SSH to first control plane
ssh a1@192.168.100.11

# Initialize cluster
sudo kubeadm init \
  --control-plane-endpoint=192.168.100.10:6443 \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16

# Configure kubectl
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/calico.yaml

# Verify
kubectl get nodes
```

### 5. Join Additional Nodes

See [r77-ansible/README.md](r77-ansible/README.md#step-2-join-additional-nodes-to-cluster) for detailed instructions.

### 6. Access Rancher

```bash
# Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts on Windows)
192.168.100.20    192.168.100.20.sslip.io rancher.local

# Access in browser
https://192.168.100.20.sslip.io

# Login with bootstrap password: admin-rancher-2024
# (Change immediately after first login!)
```

## Network Layout

| Component           | Hostname      | IP Address      | VMID | Resources           |
|---------------------|---------------|-----------------|------|---------------------|
| Load Balancer       | k8s-lb        | 192.168.100.10  | 110  | 2 CPU, 1GB, 15GB    |
| Control Plane 1     | k8s-cp1       | 192.168.100.11  | 111  | 2 CPU, 4GB, 50GB    |
| Control Plane 2     | k8s-cp2       | 192.168.100.12  | 112  | 2 CPU, 4GB, 50GB    |
| Control Plane 3     | k8s-cp3       | 192.168.100.13  | 113  | 2 CPU, 4GB, 50GB    |
| Worker 4            | k8s-worker4   | 192.168.100.14  | 114  | 2 CPU, 4GB, 50GB    |
| Worker 5            | k8s-worker5   | 192.168.100.15  | 115  | 2 CPU, 4GB, 50GB    |
| Worker 6            | k8s-worker6   | 192.168.100.16  | 116  | 2 CPU, 4GB, 50GB    |
| Jump Server         | k8s-jump      | 192.168.100.19  | 119  | 1 CPU, 1GB, 8GB     |
| Rancher             | k8s-rancher   | 192.168.100.20  | 120  | 4 CPU, 6GB, 60GB    |

**Gateway**: 192.168.100.3
**DNS**: 8.8.8.8, 8.8.4.4

## Technology Stack

### Infrastructure
- **Proxmox VE** - Virtualization platform
- **Terraform** (bpg/proxmox provider ~0.86.0)
- **Ansible** - Configuration management

### Kubernetes
- **Kubernetes v1.34** - Main cluster (kubeadm)
- **K3s v1.33** - Rancher server (lightweight K8s)
- **Calico v3.31.0** - CNI network plugin
- **containerd** - Container runtime

### Management
- **Rancher v2.12.3** - Multi-cluster management UI
- **nginx** - Load balancer for K8s API
- **nginx-ingress v1.14.0** - Ingress controller for Rancher
- **cert-manager v1.19.1** - Certificate management

## Project Structure

```
r7700/
├── README.md                    # This file
├── CLAUDE.md                    # Instructions for Claude Code
├── .gitignore                   # Git ignore patterns
│
├── r77-tf/                      # Terraform infrastructure
│   ├── keys/                    # SSH public keys
│   ├── modules/                 # Reusable modules
│   │   ├── vm/                  # VM module
│   │   └── lxc/                 # LXC module
│   └── components/              # Deployment components
│       ├── k8s-cluster/         # Main K8s cluster (7 VMs)
│       ├── k8s-jump/            # Jump server
│       └── k8s-rancher/         # Rancher server
│
└── r77-ansible/                 # Ansible configuration
    ├── ansible.cfg              # Ansible settings
    ├── inventory.yml            # All hosts and IPs
    ├── setup-jump.yml           # Jump server setup
    ├── setup-lb.yml             # Load balancer setup
    ├── setup-k8s.yml            # K8s cluster setup
    ├── rancher-setup.yml        # Rancher installation
    ├── install-nginx-ingress.yml # Ingress controller
    ├── reset-k8s.yml            # Cluster reset
    └── scripts/                 # Bash scripts
        ├── k8s-lb-setup.sh      # LB configuration
        └── k8s-node-setup.sh    # Node preparation
```

## Common Operations

### SSH Access

```bash
# Jump server
ssh a1@192.168.100.19

# Control planes
ssh a1@192.168.100.11  # cp1
ssh a1@192.168.100.12  # cp2
ssh a1@192.168.100.13  # cp3

# Workers
ssh a1@192.168.100.14  # worker4
ssh a1@192.168.100.15  # worker5
ssh a1@192.168.100.16  # worker6

# Rancher
ssh a1@192.168.100.20
```

### Cluster Management

```bash
# From jump server or any control plane
kubectl get nodes
kubectl get pods -A
kubectl top nodes

# From Rancher server
sudo kubectl get nodes  # K3s cluster
```

### Destroy and Rebuild

```bash
# Reset K8s cluster (keeps VMs)
cd r77-ansible
ansible-playbook reset-k8s.yml

# Destroy VMs
cd r77-tf/components/k8s-cluster
terraform destroy

# Rebuild
terraform apply
cd ../../../r77-ansible
ansible-playbook setup-lb.yml setup-k8s.yml
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Credentials**: `.tfvars` files are gitignored - they contain API tokens
2. **SSH Keys**: Only public keys are tracked; private keys are gitignored
3. **Rancher Password**: Change `admin-rancher-2024` immediately after first login
4. **Certificates**: Rancher uses self-signed certs; use Let's Encrypt for production
5. **Firewall**: Consider restricting access to management IPs only
6. **Updates**: Keep Kubernetes, Rancher, and Proxmox up to date

## Backup Strategy

See [Velero backup documentation](r77-ansible/README.md#backup-and-restore) for zero-downtime cluster backups.

Recommended approach:
- **etcd snapshots** - Cluster state (fast recovery)
- **Velero** - Application-level backups (PVs + configs)
- **ZFS snapshots** - VM-level disaster recovery

## Troubleshooting

### Rancher Not Accessible
```bash
# Check nginx-ingress
ssh a1@192.168.100.20
sudo kubectl get pods -n ingress-nginx

# Add to /etc/hosts if DNS fails
192.168.100.20    192.168.100.20.sslip.io
```

### K8s Cluster Issues
```bash
# Check cluster status
ssh a1@192.168.100.11
kubectl get nodes
kubectl get pods -A

# Check load balancer
ssh a1@192.168.100.10
sudo systemctl status nginx
```

### Ansible Connection Issues
```bash
# Test connectivity
ansible all -m ping

# Check SSH
ssh -v a1@192.168.100.11
```

## Contributing

This is a personal infrastructure project, but suggestions are welcome via issues.

## License

MIT License - See LICENSE file for details.

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [K3s Documentation](https://docs.k3s.io/)
- [Rancher Documentation](https://rancher.com/docs/)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)

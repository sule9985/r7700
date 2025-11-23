# r77-ansible

Ansible automation for Proxmox-based infrastructure. Organized by service type for easy management.

## Directory Structure

```
r77-ansible/
├── ansible.cfg              # Ansible configuration
├── inventory.yml            # All hosts and IPs
├── collections/             # Ansible collections (ansible.posix, community.general)
├── k8s/                     # Kubernetes cluster automation
│   ├── scripts/             # Setup bash scripts
│   ├── k8s-setup.yml        # Prepare K8s nodes
│   ├── k8s-lb-setup.yml     # Configure nginx load balancer
│   ├── k8s-jump-setup.yml   # Setup jump server
│   ├── k8s-copy-scripts.yml # Copy scripts to VMs
│   └── k8s-reset.yml        # Destroy cluster
├── jmeter/                  # Load testing setup
│   ├── docs/                # Quick start and usage guides
│   ├── tests/               # Sample JMeter test plans (.jmx)
│   ├── jmeter-setup.yml     # Install and configure JMeter
│   └── fix-jmeter-permissions.yml
├── grafana-stack/           # Monitoring infrastructure
│   ├── docs/                # Deployment and version guides
│   ├── grafana-stack-setup.yml        # Automated Ansible setup
│   ├── grafana-stack-manual-setup.sh  # Manual bash setup (for learning)
│   └── grafana-setup.yml              # Standalone Grafana setup
├── rancher/                 # Rancher management platform
│   ├── rancher-setup.yml    # Install Rancher (K3s-based)
│   ├── rancher-check.yml    # Verify installation
│   ├── rancher-install-nginx-ingress.yml
│   └── fix-rancher-access.yml
└── lxc/                     # LXC container utilities
    ├── lxc-initial-setup.yml    # Bootstrap new containers
    └── setup-lxc-network.sh     # Network configuration helper
```

## Quick Start

### Test Connectivity
```bash
ansible all -m ping
```

### Deploy Kubernetes Cluster
```bash
# Setup infrastructure components
ansible-playbook k8s/k8s-jump-setup.yml   # Jump server (optional)
ansible-playbook k8s/k8s-lb-setup.yml     # Load balancer
ansible-playbook k8s/k8s-setup.yml        # Prepare all K8s nodes

# Then manually initialize cluster (see K8s section below)
```

### Deploy Monitoring Stack
```bash
# Automated Ansible deployment
ansible-playbook grafana-stack/grafana-stack-setup.yml

# Or manual bash installation (for learning)
# Copy script to LXC container first, then:
./grafana-stack/grafana-stack-manual-setup.sh
```

### Deploy Load Testing
```bash
ansible-playbook jmeter/jmeter-setup.yml

# See jmeter/docs/ for usage guides
```

### Deploy Rancher
```bash
ansible-playbook rancher/rancher-setup.yml
ansible-playbook rancher/rancher-check.yml
```

## Component Details

### Kubernetes Cluster (k8s/)

**What each playbook does:**

- **k8s-setup.yml**: Prepares all nodes with containerd, kubeadm, kubelet, kubectl v1.34
  - Disables swap
  - Configures /etc/hosts
  - Loads kernel modules
  - Configures sysctl
  - Installs container runtime and K8s packages

- **k8s-lb-setup.yml**: Configures nginx TCP load balancer for K8s API (port 6443)

- **k8s-jump-setup.yml**: Sets up jump server with kubectl and utilities

- **k8s-reset.yml**: Destroys cluster (CAUTION: runs `kubeadm reset -f`)

**Manual cluster initialization** (after running playbooks):

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

# Get join commands
kubeadm token create --print-join-command  # For workers
sudo kubeadm init phase upload-certs --upload-certs  # For control planes
```

See full K8s setup guide in CLAUDE.md or original README sections.

### Grafana Stack (grafana-stack/)

Monitoring infrastructure with Grafana, Prometheus, Loki, AlertManager, and Proxmox PVE Exporter.

**Deployment options:**

1. **Automated (Ansible)**: `ansible-playbook grafana-stack/grafana-stack-setup.yml`
2. **Manual (Bash)**: `./grafana-stack/grafana-stack-manual-setup.sh` (for learning)

**Service versions:**
- Grafana: 12.3.0
- Prometheus: 3.7.3 (15-day retention)
- Loki: 3.6.0 (7-day retention)
- AlertManager: 0.29.0

**Post-installation:**
- Access Grafana at http://192.168.100.40:3000 (admin/admin)
- Configure Proxmox credentials in `/etc/prometheus-pve-exporter/pve.yml`
- Import dashboards (Proxmox: 10347, JMeter: 13865)

See `grafana-stack/docs/` for detailed guides.

### JMeter (jmeter/)

Apache JMeter load testing server with Prometheus metrics integration.

**Components:**
- JMeter 5.6.3 with plugins (Standard, Extras, WebDriver, Hadoop)
- Prometheus JMeter plugin for real-time metrics
- Sample test plans in `tests/`

**Usage:**
```bash
# Non-GUI mode (recommended)
jmeter -n -t test.jmx -l results.jtl

# With Prometheus metrics export
jmeter -n -t jmeter-prometheus-test.jmx -l results.jtl
# Metrics available at http://192.168.100.23:9270/metrics
```

See `jmeter/docs/JMETER_QUICK_START.md` for 5-minute guide.

### Rancher (rancher/)

Kubernetes management platform (K3s-based).

**Installation:**
- Deployed on k8s-jump (192.168.100.19)
- Access at https://192.168.100.19
- Includes local path provisioner for storage

### LXC Utilities (lxc/)

Helpers for setting up Debian-based LXC containers.

**lxc-initial-setup.yml**: Bootstrap new containers with:
- Network configuration
- SSH server
- Essential packages (python3, sudo, curl)
- Locale configuration

**setup-lxc-network.sh**: Standalone script for manual network setup

**Note**: LXC containers don't use cloud-init like VMs. Network must be configured manually.

## Common Tasks

### Update Inventory
Edit `inventory.yml` to change host IPs or add new hosts.

### Reset Kubernetes
```bash
ansible-playbook k8s/k8s-reset.yml
ansible-playbook k8s/k8s-reset.yml -e "reboot_after_reset=false"  # Skip reboot
```

### Check Grafana Stack Status
```bash
ansible grafana_stack -m shell -a "systemctl status grafana-server prometheus loki alertmanager --no-pager"
```

### View Service Logs
```bash
ansible <host> -m shell -a "journalctl -u <service-name> -n 50 --no-pager"
```

## Documentation

- **Kubernetes**: See CLAUDE.md for detailed cluster setup
- **Grafana Stack**: See `grafana-stack/docs/GRAFANA_STACK_DEPLOYMENT.md`
- **JMeter**: See `jmeter/docs/JMETER_QUICK_START.md`
- **LXC**: See `LXC_MANUAL_SETUP_GUIDE.md` (project root)

## Customization

- **Change IPs**: Edit `inventory.yml`
- **Change K8s versions**: Edit version variables in `k8s/k8s-setup.yml`
- **Change monitoring retention**: Edit `grafana-stack/grafana-stack-setup.yml`
- **Add Prometheus targets**: Edit `/etc/prometheus/prometheus.yml` on grafana-stack

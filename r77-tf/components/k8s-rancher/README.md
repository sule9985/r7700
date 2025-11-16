# k8s-rancher

Rancher management server running on K3s (lightweight Kubernetes).

## Overview

This component provisions a single VM that runs:
- **K3s** (lightweight Kubernetes distribution)
- **Rancher** (Kubernetes management platform)

Rancher provides a web UI to manage multiple Kubernetes clusters, including your main k8s-cluster.

## Specifications

- **Hostname**: k8s-rancher
- **IP Address**: 192.168.100.20
- **Resources**: 4 CPU, 6GB RAM, 60GB storage
- **OS**: Debian 13 (cloned from template)
- **User**: a1 (configured via cloud-init)

## Quick Start

### 1. Deploy VM with Terraform

```bash
# Navigate to component directory
cd r77-tf/components/k8s-rancher

# Configure credentials (if not already done)
export TF_VAR_proxmox_api_url="https://192.168.100.4:8006"
export TF_VAR_proxmox_api_token_id="pve-terraform-user@pve!terraform-apitoken=..."

# Deploy Rancher VM
terraform init
terraform plan
terraform apply
```

### 2. Install K3s + Rancher with Ansible

```bash
# Navigate to Ansible directory
cd ../../../r77-ansible

# Test connectivity
ansible k8s_rancher -m ping

# Install K3s and Rancher (takes ~10-15 minutes)
ansible-playbook setup-rancher.yml
```

### 3. Access Rancher UI

After installation completes:

1. **Open browser**: https://192.168.100.20.sslip.io
   - Or directly: https://192.168.100.20 (self-signed cert warning)

2. **Login**:
   - Bootstrap Password: `admin-rancher-2024` (change this in playbook!)

3. **First-time setup**:
   - Set new admin password
   - Accept license agreement
   - Complete initial setup

## What Gets Installed

The Ansible playbook ([setup-rancher.yml](../../r77-ansible/setup-rancher.yml)) installs:

1. **K3s v1.28.5** - Lightweight Kubernetes
   - Single-node cluster
   - Traefik disabled (Rancher uses its own ingress)
   - Kubeconfig at `/etc/rancher/k3s/k3s.yaml`

2. **Helm 3** - Kubernetes package manager

3. **cert-manager v1.13.3** - Certificate management
   - Required by Rancher for TLS

4. **Rancher v2.8.0** - Management platform
   - Single replica (appropriate for single-node)
   - Web UI at https://192.168.100.20

## Managing Your K8s Cluster from Rancher

Once Rancher is running, you can import your existing k8s-cluster:

### Import Existing Cluster

1. Login to Rancher UI
2. Click **"Import Existing"** cluster
3. Give it a name (e.g., "k8s-cluster")
4. Copy the kubectl command provided
5. Run on your jump server or any control plane:
   ```bash
   ssh a1@192.168.100.19  # Jump server
   # Paste the kubectl apply command from Rancher
   ```

6. Cluster will appear in Rancher UI with full management capabilities

### Features Available

- **Cluster Dashboard** - Resource usage, health status
- **Workload Management** - Deploy apps via UI
- **Monitoring** - Prometheus + Grafana integration
- **Logging** - Centralized log collection
- **Backup/Restore** - Rancher Backup Operator
- **Multi-cluster Apps** - Deploy across multiple clusters
- **RBAC Management** - User/group permissions
- **Catalog Apps** - Helm chart marketplace

## Accessing K3s Cluster

### From Rancher VM

```bash
ssh a1@192.168.100.20
sudo kubectl get nodes
sudo kubectl get pods -A
```

### From Local Machine

```bash
# Copy kubeconfig
scp a1@192.168.100.20:/etc/rancher/k3s/k3s.yaml ~/.kube/rancher-config

# Edit the file and change server IP
sed -i 's/127.0.0.1/192.168.100.20/g' ~/.kube/rancher-config

# Use it
export KUBECONFIG=~/.kube/rancher-config
kubectl get nodes
```

## Customization

### Change Rancher Version

Edit [setup-rancher.yml](../../r77-ansible/setup-rancher.yml):
```yaml
vars:
  rancher_version: "2.8.0"  # Update this
```

### Change Bootstrap Password

**IMPORTANT**: Change the default password!

Edit [setup-rancher.yml](../../r77-ansible/setup-rancher.yml):
```yaml
vars:
  bootstrap_password: "your-secure-password-here"
```

### Use Custom Domain

If you have a domain, update:
```yaml
vars:
  rancher_hostname: "rancher.yourdomain.com"
```

Then configure DNS to point to 192.168.100.20.

### Increase Replicas

For HA, you'd need multiple VMs. For single VM, keep `replicas=1`.

## Troubleshooting

### Check K3s Status

```bash
ssh a1@192.168.100.20
sudo systemctl status k3s
sudo kubectl get nodes
```

### Check Rancher Pods

```bash
ssh a1@192.168.100.20
sudo kubectl get pods -n cattle-system
sudo kubectl logs -n cattle-system -l app=rancher
```

### Reset Installation

```bash
# On Rancher VM
ssh a1@192.168.100.20
sudo /usr/local/bin/k3s-uninstall.sh

# Re-run Ansible playbook
cd r77-ansible
ansible-playbook setup-rancher.yml
```

## Backup and Restore

### Backup K3s

```bash
ssh a1@192.168.100.20
sudo cp /etc/rancher/k3s/k3s.yaml ~/k3s-backup-$(date +%Y%m%d).yaml
```

### Backup Rancher Data

Use Rancher's built-in backup feature:
1. In Rancher UI: **Cluster > Backup**
2. Install **rancher-backup** operator
3. Create backup schedule

## Security Notes

- **Change bootstrap password** immediately after first login
- **Enable 2FA** in Rancher user settings
- **Use proper domain + Let's Encrypt** for production
- **Firewall rules** - Only allow access from trusted IPs
- **Regular updates** - Keep K3s and Rancher up to date

## Resources

- K3s Documentation: https://docs.k3s.io/
- Rancher Documentation: https://rancher.com/docs/
- Rancher Forums: https://forums.rancher.com/

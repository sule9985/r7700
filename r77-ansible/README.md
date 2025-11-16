# r77-ansible

Simple Ansible configuration for Proxmox K8s cluster.

## Structure

```
r77-ansible/
├── ansible.cfg       # Ansible configuration
├── inventory.yml     # All hosts and IPs
├── copy-scripts.yml  # Copy setup scripts to VMs (optional)
├── setup-jump.yml    # Setup jump server (bastion host)
├── setup-lb.yml      # Setup nginx load balancer
├── setup-k8s.yml     # Setup Kubernetes cluster (runs k8s-node-setup.sh)
├── reset-k8s.yml     # Reset/destroy Kubernetes cluster
└── scripts/          # Bash scripts for node setup
    ├── k8s-lb-setup.sh      # Load balancer setup script
    └── k8s-node-setup.sh    # K8s node setup script (used by setup-k8s.yml)
```

## Quick Start

```bash
# Test connectivity
ansible all -m ping

# Setup jump server (optional but recommended)
ansible-playbook setup-jump.yml

# Setup nginx load balancer
ansible-playbook setup-lb.yml

# Setup Kubernetes
ansible-playbook setup-k8s.yml

# Or run all at once
ansible-playbook setup-jump.yml setup-lb.yml setup-k8s.yml
```

## What Each Playbook Does

### setup-jump.yml
- Installs kubectl (K8s v1.34) for cluster management
- Installs basic utilities (vim, curl, wget, git, tmux, htop, net-tools)
- Creates .kube directory for kubeconfig
- Provides secure entry point to access cluster nodes

**Note**: After cluster initialization, copy kubeconfig from control plane to jump server.

### setup-lb.yml
- Installs nginx and libnginx-mod-stream (TCP load balancing module)
- Configures TCP load balancing for K8s API (port 6443)
- Balances across 3 control plane nodes

### setup-k8s.yml
- Copies and executes `scripts/k8s-node-setup.sh` on all K8s nodes
- The script performs:
  - Disables swap
  - Configures /etc/hosts with all cluster nodes
  - Loads kernel modules (overlay, br_netfilter, xt_set, ip_set) with persistence
  - Configures sysctl for networking (IPv4 and IPv6 support)
  - Installs containerd with SystemdCgroup enabled and CNI bin_dir configured
  - Installs kubelet, kubeadm, kubectl (version 1.34)
  - Holds packages to prevent accidental upgrades

**Note**: This playbook only prepares the nodes. Cluster initialization is done manually (see below).

### reset-k8s.yml
- Runs `kubeadm reset -f` on all nodes
- Removes all Kubernetes directories (etcd, kubelet, CNI, configs)
- Removes kubectl configs for users
- Reboots all nodes (optional, controlled by variable)

**CAUTION**: This destroys your cluster! Use when starting over.

## Customization

Edit `inventory.yml` to change IPs.

Edit nginx upstream in `setup-lb.yml` if you change control plane IPs.

## Manual Steps After Ansible

### Step 1: Initialize the Cluster

After running the playbooks, you need to manually initialize the first control plane:

```bash
# SSH to first control plane
ssh a1@192.168.100.11

# Initialize cluster
sudo kubeadm init \
  --control-plane-endpoint=192.168.100.10:6443 \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16

# Configure kubectl for user a1
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/calico.yaml

# Verify
kubectl get nodes
kubectl get pods -n kube-system
```

### Step 2: Join Additional Nodes to Cluster

Now join the remaining control planes and workers.

#### Get Join Tokens (on k8s-cp1)

```bash
# SSH to first control plane
ssh a1@192.168.100.11

# Get worker join command
kubeadm token create --print-join-command
# Output: kubeadm join 192.168.100.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Get certificate key for control planes (requires sudo)
sudo kubeadm init phase upload-certs --upload-certs
# Output: certificate key: <cert-key>
```

#### Join Additional Control Planes (k8s-cp2, k8s-cp3)

```bash
# SSH to each control plane node
ssh a1@192.168.100.12  # or .13

# Run join command with control-plane flags
sudo kubeadm join 192.168.100.10:6443 \
  --token l4fjx5.xq3df3ljlobhxmuj \
  --discovery-token-ca-cert-hash sha256:a663d8ed907bf67f70d4ccf949665c3e80816bb19c0cf0eb1a366e2b111d40d5 \
  --control-plane \
  --certificate-key 23e6c8b4715508860e6c8071b706aa1e0ebb2a41eaba8bb1fd386a6deea35c1d
```

**Note**: Replace `--token`, `--discovery-token-ca-cert-hash`, and `--certificate-key` with YOUR actual values from Step 1.

#### Join Worker Nodes (k8s-worker4, k8s-worker5, k8s-worker6)

```bash
# SSH to each worker node
ssh a1@192.168.100.14  # or .15, .16

# Run join command WITHOUT control-plane flags
sudo kubeadm join 192.168.100.10:6443 \
  --token l4fjx5.xq3df3ljlobhxmuj \
  --discovery-token-ca-cert-hash sha256:a663d8ed907bf67f70d4ccf949665c3e80816bb19c0cf0eb1a366e2b111d40d5
```

**Note**: Replace `--token` and `--discovery-token-ca-cert-hash` with YOUR actual values from Step 1.

### Step 3: Verify Cluster

```bash
# On k8s-cp1
kubectl get nodes

# Should show all 6 nodes:
# - k8s-cp1, k8s-cp2, k8s-cp3 (control planes - Ready, control-plane)
# - k8s-worker4, k8s-worker5, k8s-worker6 (workers - Ready)
# Note: Load balancer (k8s-lb) and jump server (k8s-jump) are NOT Kubernetes nodes
```

### Step 4: Setup Jump Server Access (Optional)

Copy kubeconfig to jump server for remote cluster management:

```bash
# From your local machine or k8s-cp1
scp a1@192.168.100.11:~/.kube/config ~/.kube/config-k8s

# Then SSH to jump server
ssh a1@192.168.100.19

# On jump server, copy the kubeconfig
scp a1@192.168.100.11:~/.kube/config ~/.kube/config

# Test kubectl access
kubectl get nodes
kubectl get pods -A
```

### Token Expiration

Tokens expire after 24 hours. If your tokens expire, generate new ones:

```bash
# On k8s-cp1
kubeadm token create --print-join-command  # New worker token
sudo kubeadm init phase upload-certs --upload-certs  # New cert key
```

## Reset Kubernetes Cluster

If you want to start over without destroying VMs in Terraform:

```bash
# Reset all Kubernetes nodes (CAUTION: Destroys cluster!)
ansible-playbook reset-k8s.yml

# Skip reboot (faster, but not as clean)
ansible-playbook reset-k8s.yml -e "reboot_after_reset=false"
```

After reset, you can re-run the setup:
```bash
ansible-playbook setup-k8s.yml
# Then follow manual initialization steps above
```

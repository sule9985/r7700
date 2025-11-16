# Quick Start Guide

Get your k8s-lb VM running in 5 minutes!

## Prerequisites

- Proxmox server accessible
- Template VMID 999 (Debian 13) created with cloud-init
- Your SSH public key ready

## Quick Setup

### 1. Configure Proxmox Connection (Choose One Method)

**Method A: Environment Variables** (Recommended)
```bash
export TF_VAR_proxmox_api_url="https://192.168.1.100:8006"
export TF_VAR_proxmox_api_token_id="root@pam!terraform=your-secret-here"
export TF_VAR_proxmox_tls_insecure=true
```

**Method B: Config File**
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your credentials
```

### 2. Deploy k8s-lb VM

```bash
# Go to k8s-cluster environment
cd environments/k8s-cluster

# Configure environment
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars - Update these values:
nano terraform.tfvars
```

Minimal configuration:
```hcl
proxmox_node   = "pve"           # Your Proxmox node name
storage_name   = "local-zfs"     # Your storage name
gateway        = "192.168.100.1" # Your network gateway
k8s_lb_ip      = "192.168.100.10"
ssh_public_key = "ssh-rsa AAAA..." # Your SSH public key
```

### 3. Deploy!

```bash
terraform init
terraform apply
```

Type `yes` when prompted.

### 4. Access Your VM

```bash
# SSH into the VM
ssh a1@192.168.100.10

# Check the VM info
terraform output
```

## What Got Created?

- **VM Name**: k8s-lb
- **CPU**: 2 cores
- **RAM**: 1GB (1024 MB)
- **Disk**: 15GB (auto-resizes from 12GB template)
- **IP**: 192.168.100.10/24 (static)
- **User**: a1 (sudo access, SSH key auth)

## Next Steps

### Add Control Plane Nodes

Edit `environments/k8s-cluster/main.tf`, add:

```hcl
module "k8s_control_plane_1" {
  source = "../../modules/vm"

  vm_name        = "k8s-cp-1"
  target_node    = var.proxmox_node
  clone_template = 999

  cores  = 2
  memory = 2048

  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = 20
  }]

  networks = [{
    model  = "virtio"
    bridge = "vmbr0"
  }]

  ip_config  = "enabled"
  ip_address = "192.168.100.11/24"
  gateway    = var.gateway

  dns_servers = var.dns_servers
  ci_user     = var.vm_user
  ssh_keys    = var.ssh_public_key

  tags = "terraform,k8s,control-plane"
}
```

Then run:
```bash
terraform apply
```

### Add Worker Nodes

Similar to control plane, but with different IP and tags:

```hcl
module "k8s_worker_1" {
  source = "../../modules/vm"

  vm_name        = "k8s-worker-1"
  # ... similar config ...
  ip_address = "192.168.100.21/24"
  tags       = "terraform,k8s,worker"
}
```

### Destroy Everything

```bash
terraform destroy
```

## Troubleshooting

**VM won't start?**
- Check template exists: `qm list | grep 999`
- Verify CloudInit drive: `qm config 999 | grep ide2`

**Can't SSH?**
- Verify IP: `terraform output`
- Check cloud-init logs: Login via Proxmox console, then `sudo cloud-init status --long`

**Disk not 15GB?**
- SSH into VM: `df -h /`
- Check cloud-init: `grep growpart /etc/cloud/cloud.cfg`

## File Structure

```
r77-tf/
├── terraform.tfvars          # Proxmox credentials (create this)
├── environments/
│   └── k8s-cluster/
│       ├── main.tf           # VM definitions
│       ├── variables.tf      # Environment variables
│       └── terraform.tfvars  # Environment config (create this)
└── modules/
    └── vm/                   # Reusable VM module
```

## Key Differences from Telmate Provider

This project uses **bpg/proxmox** provider (not telmate):
- ✅ Better maintained
- ✅ Simpler cloud-init configuration
- ✅ Better error messages
- ✅ Active development

**API Token Format Changed:**
- Old (telmate): Separate `token_id` and `token_secret`
- New (bpg): Combined `user@pam!name=secret`

For detailed setup, see [SETUP.md](SETUP.md)

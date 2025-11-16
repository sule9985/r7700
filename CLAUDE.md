# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Proxmox infrastructure-as-code project using Terraform and Ansible:
- `r77-tf/`: Terraform modules and environments for Proxmox VM/LXC provisioning
- `r77-ansible/`: Ansible playbooks for configuration management (configures VMs provisioned by Terraform)

## Core Architecture

### Terraform Provider
Uses **bpg/proxmox** provider (NOT telmate/proxmox):
- API token format: `user@pam!terraform=secret` (combined, not separate)
- Version: ~> 0.86.0
- Key difference: Better cloud-init support, actively maintained

### Module Structure
```
r77-tf/
├── main.tf                    # Root provider configuration
├── variables.tf               # Global variables (API credentials, DNS, gateway)
├── modules/
│   ├── vm/                    # Reusable VM module (QEMU with cloud-init)
│   └── lxc/                   # Reusable LXC container module
└── environments/
    └── k8s-cluster/           # Environment-specific deployments
```

### VM Module Architecture
The VM module ([modules/vm/main.tf](r77-tf/modules/vm/main.tf)) uses:
1. **Clone-based workflow**: VMs clone from template (e.g., VMID 998/999)
2. **Cloud-init integration**: Static IP, SSH keys, user creation
3. **Automatic disk resizing**: Terraform resizes during clone if `disks[].size` > template size
4. **QEMU guest agent**: Required for proper cloud-init functionality
5. **Lifecycle ignore**: Ignores cloud-init changes to prevent regeneration

Key resource: `proxmox_virtual_environment_vm` (not `proxmox_vm_qemu`)

### LXC Module
The LXC module ([modules/lxc/main.tf](r77-tf/modules/lxc/main.tf)) supports:
- Unprivileged containers by default
- Nesting for Docker support
- Network configuration with DHCP or static IP

### Environments
Each environment (e.g., `k8s-cluster`) is a standalone Terraform workspace with:
- Own provider configuration
- Own variables and tfvars
- References to shared modules via relative paths (`../../modules/vm`)

The k8s-cluster environment deploys:
- 1 load balancer VM (k8s-lb)
- 3 control plane nodes (dynamic via `for_each`)
- 3 worker nodes (dynamic via `for_each`)

## Ansible Project Architecture

### Structure
Simple flat structure with minimal layering:
```
r77-ansible/
├── ansible.cfg       # Simple config (user, SSH key)
├── inventory.yml     # All hosts and IPs in one file
├── setup-lb.yml      # Setup nginx load balancer
└── setup-k8s.yml     # Setup Kubernetes cluster
```

### Playbook Purposes
- **setup-lb.yml**: Installs nginx + libnginx-mod-stream (TCP load balancing module), configures load balancing for K8s API (port 6443) across 3 control plane nodes
- **setup-k8s.yml**: Prepares all K8s nodes (disable swap, kernel modules, sysctl), installs containerd with SystemdCgroup enabled, installs K8s packages, initializes first control plane, installs Calico CNI v3.31.0

## Common Commands

### Ansible Commands
```bash
# From r77-ansible directory
cd r77-ansible

# Test connectivity
ansible all -m ping

# Run playbooks individually
ansible-playbook setup-lb.yml
ansible-playbook setup-k8s.yml

# Or run both at once
ansible-playbook setup-lb.yml setup-k8s.yml

# Check mode (dry run)
ansible-playbook setup-lb.yml --check

# Limit to specific hosts
ansible-playbook setup-k8s.yml --limit k8s_control_plane
```

### Terraform Commands

#### Initial Setup
```bash
# Root level - configure Proxmox credentials
cd r77-tf
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with API credentials

# OR use environment variables (recommended)
export TF_VAR_proxmox_api_url="https://proxmox:8006"
export TF_VAR_proxmox_api_token_id="user@pam!terraform=secret"
export TF_VAR_proxmox_tls_insecure=true
```

#### Working with Environments
```bash
# Deploy k8s cluster
cd r77-tf/environments/k8s-cluster
terraform init
terraform plan
terraform apply

# Destroy environment
terraform destroy

# View outputs
terraform output

# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

#### Template Management
Templates are created manually in Proxmox, then referenced by VMID:
```bash
# Create template from Debian 13 raw image (run on Proxmox host)
cd r77-tf/proxmox-scripts-tools
bash create-vm-from-debian-13-generic-raw.sh
```

Expected template setup:
- VMID 998 or 999
- Debian 13 with cloud-init and qemu-guest-agent installed
- CloudInit drive on ide2
- User `a1` with sudo NOPASSWD configured

## Key Configuration Points

### SSH Keys
SSH public keys are stored in [r77-tf/keys/vm-deb13.pub](r77-tf/keys/vm-deb13.pub) and referenced via:
```hcl
data "local_file" "ssh_public_key" {
  filename = "${path.root}/../../keys/vm-deb13.pub"
}
```

### Network Configuration
Default network settings in [r77-tf/variables.tf](r77-tf/variables.tf:19-29):
- Gateway: 192.168.100.1
- DNS: 8.8.8.8, 8.8.4.4
Can be overridden per environment in environment-specific variables.tf

### Storage
Default storage: `local-zfs` (configurable via `storage_name` variable)
- Disks use `file_format = "raw"` for ZFS optimization
- SSDs enabled with TRIM support

### Cloud-init Configuration
VMs use static IP configuration via cloud-init:
```hcl
ip_address = "192.168.100.10/24"  # CIDR notation required
gateway    = "192.168.100.1"
```

## Workflow: Terraform + Ansible

The typical workflow combines both tools:

```bash
# 1. Provision infrastructure with Terraform
cd r77-tf/environments/k8s-cluster
terraform apply

# 2. Get IP addresses from outputs
terraform output

# 3. Update Ansible inventory (if IPs changed)
cd ../../../r77-ansible
# Edit inventory.yml with actual IPs

# 4. Configure with Ansible
ansible-playbook setup-lb.yml setup-k8s.yml

# 5. Verify K8s cluster (SSH to first control plane)
ssh a1@192.168.100.11
kubectl get nodes
```

### Terraform-Ansible Integration Points
- SSH user configured in Terraform cloud-init: `a1`
- SSH key: `~/.ssh/vm-deb13` (private), `r77-tf/keys/vm-deb13.pub` (public deployed via Terraform)
- Ansible [inventory.yml](r77-ansible/inventory.yml) IPs mirror Terraform outputs
- nginx upstream in [setup-lb.yml](r77-ansible/setup-lb.yml) must match control plane IPs
- Load balancer IP (192.168.100.10) should match Terraform variable `k8s_lb_ip`

## Working with VM Resources

### Adding a New VM to an Environment
1. Add module block in environment's [main.tf](r77-tf/environments/k8s-cluster/main.tf)
2. Specify unique VMID (avoid conflicts)
3. Configure disks array with interface, datastore_id, size
4. Set ip_address with CIDR notation (/24)
5. Use trimspace() when passing SSH keys from data source

### Adding Ansible Configuration for New Hosts
After adding VMs in Terraform:
1. Add hosts to `r77-ansible/inventory.yml` under appropriate groups
2. Update nginx upstream servers in `setup-lb.yml` if adding control planes
3. Run playbooks against new hosts

### Modifying Cluster Size
Edit [variables.tf](r77-tf/environments/k8s-cluster/variables.tf) maps:
- `control_plane_nodes`: K8s control plane definitions (lines 52-65)
- `worker_nodes`: K8s worker definitions (lines 67-80)

Both use `for_each` in [main.tf](r77-tf/environments/k8s-cluster/main.tf:76-106), so adding/removing map entries automatically provisions/destroys VMs.

When changing cluster size, also update:
- [r77-ansible/inventory.yml](r77-ansible/inventory.yml) with new IPs
- [r77-ansible/setup-lb.yml](r77-ansible/setup-lb.yml) nginx upstream if control plane IPs change

## Important Implementation Details

### Disk Resizing
The VM module automatically resizes disks during clone if the requested size is larger than the template. The template must have cloud-init with `growpart` and `resizefs` modules enabled.

### Lifecycle Management
The VM module ignores changes to `initialization` block ([modules/vm/main.tf:104-109](r77-tf/modules/vm/main.tf#L104-L109)) to prevent cloud-init regeneration on every apply.

### API Token Permissions
Required Proxmox permissions for the API token:
- VM.Allocate
- VM.Clone
- VM.Config.Disk
- VM.Config.Network
- VM.Config.Options
- Datastore.AllocateSpace

### Clone Settings
VMs use `full_clone = true` to create independent copies (not linked clones). This is set in environment configurations.

## Security Notes

- terraform.tfvars files are gitignored (contain API credentials)
- API tokens are marked as sensitive variables
- SSH private keys are NOT stored in this repo (only public keys in keys/)
- Use environment variables for credentials in CI/CD pipelines

## Troubleshooting Common Issues

### TLS Certificate Errors
Set `proxmox_tls_insecure = true` in terraform.tfvars for self-signed certificates.

### Template Not Found
Verify template exists on target node:
```bash
qm list | grep 998  # or 999
```

### Cloud-init Not Working
Check CloudInit drive exists:
```bash
qm config 998 | grep ide2
# Should show: ide2: local-zfs:vm-998-cloudinit,media=cdrom
```

### VM Won't Start After Clone
Ensure QEMU guest agent is installed in template and enabled:
```bash
qm config 998 | grep agent
# Should show: agent: enabled=1
```

### Disk Not Resizing
Verify template has growpart/resizefs in cloud-init config. SSH into VM and check:
```bash
df -h /  # Check actual size
sudo cloud-init status --long  # Check cloud-init execution
```

# Setup Guide

## Prerequisites

1. **Terraform** >= 1.0
2. **Proxmox VE** server with API access
3. **API Token** created in Proxmox

## Step 1: Create Proxmox API Token

1. Log into your Proxmox web interface
2. Navigate to **Datacenter** > **Permissions** > **API Tokens**
3. Click **Add** to create a new token
4. Format: `user@pam!terraform` (e.g., `root@pam!terraform`)
5. **Important**: Copy the token secret - it's shown only once!
6. The full token will be in format: `user@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Required Permissions

Ensure your API token has these permissions:
- VM.Allocate
- VM.Clone
- VM.Config.Disk
- VM.Config.Network
- VM.Config.Options
- Datastore.AllocateSpace

## Step 2: Configure Proxmox Credentials

You have two options for configuring Proxmox credentials:

### Option A: Environment Variables (Recommended for Security)

```bash
export TF_VAR_proxmox_api_url="https://your-proxmox-server:8006"
export TF_VAR_proxmox_api_token_id="user@pam!terraform=your-secret-here"
export TF_VAR_proxmox_tls_insecure=true
```

Add these to your `~/.bashrc` or `~/.zshrc` for persistence.

### Option B: Root terraform.tfvars File

```bash
# In project root
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Edit with your actual values:
```hcl
proxmox_api_url      = "https://192.168.1.100:8006"
proxmox_api_token_id = "root@pam!terraform=12345678-1234-1234-1234-123456789abc"
proxmox_tls_insecure = true
```

**Important**: Never commit `terraform.tfvars` to version control!

## Step 3: Prepare VM Template

Before deploying VMs, you need a cloud-init enabled template:

### Quick Template Setup (Debian 13 Example)

1. Create a VM in Proxmox (VMID: 999)
2. Install Debian 13 with these settings:
   - 2 cores, 2GB RAM, 12GB disk
   - Create user `a1` with sudo access

3. Inside the VM, run:
```bash
# Install required packages
sudo apt update
sudo apt install -y cloud-init qemu-guest-agent

# Configure sudo without password (for automation)
echo "a1 ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/a1

# Clean the system
sudo rm -f /etc/ssh/ssh_host_*
sudo cloud-init clean --logs
sudo apt clean
sudo shutdown -h now
```

4. In Proxmox shell, add CloudInit drive:
```bash
qm set 999 --ide2 local-zfs:cloudinit
qm set 999 --agent enabled=1
```

5. Convert to template:
```bash
qm template 999
```

## Step 4: Deploy an Environment

### Example: K8s Cluster

```bash
# Navigate to the environment
cd environments/k8s-cluster

# Configure environment-specific settings
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Edit environment values:
```hcl
proxmox_node = "pve"
storage_name = "local-zfs"
gateway      = "192.168.100.1"
k8s_lb_ip    = "192.168.100.10"
vm_user      = "a1"
ssh_public_key = "ssh-rsa AAAAB3NzaC... your-key"
```

### Initialize and Deploy

```bash
# Initialize Terraform (downloads bpg/proxmox provider)
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply
```

### Verify Deployment

```bash
# Check outputs
terraform output

# SSH into the VM
ssh a1@192.168.100.10
```

## Step 5: Managing Multiple Environments

Each environment is independent:

```bash
# Development environment
cd environments/dev
terraform init
terraform apply

# Production environment
cd environments/prod
terraform init
terraform apply
```

All environments share the same Proxmox credentials (from root or environment variables).

## Troubleshooting

### TLS Certificate Errors

If you see SSL/TLS errors:
```hcl
proxmox_tls_insecure = true
```

### Template Not Found

Ensure the template VMID exists:
```bash
qm list | grep 999
```

### Cloud-init Not Working

Verify CloudInit drive was added:
```bash
qm config 999 | grep ide2
# Should show: ide2: local-zfs:vm-999-cloudinit,media=cdrom
```

### Disk Not Resizing

Ensure your template has `growpart` and `resizefs` in cloud-init config:
```bash
# Inside the template VM before converting
grep -A 5 "cloud_init_modules" /etc/cloud/cloud.cfg
```

## Provider Information

This project uses the **bpg/proxmox** provider (not telmate/proxmox):
- More actively maintained
- Better Terraform 1.x support
- Improved cloud-init handling
- Better documentation

Provider documentation: https://registry.terraform.io/providers/bpg/proxmox/latest/docs

# k8s-jump

Lightweight jump server (bastion host) for secure access to the Kubernetes cluster.

## Overview

This component provisions a minimal Debian 13 VM that serves as a jump server for accessing the Kubernetes cluster nodes. The jump server provides a secure entry point to the cluster network.

## Specifications

- **Hostname**: k8s-jump
- **IP Address**: 192.168.100.19
- **Resources**: 1 CPU, 1GB RAM, 8GB storage
- **OS**: Debian 13 (cloned from template)
- **User**: a1 (configured via cloud-init)

## Quick Start

```bash
# Navigate to component directory
cd r77-tf/components/k8s-jump

# Configure credentials (choose one method)
# Method 1: Copy and edit tfvars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox credentials

# Method 2: Use environment variables (recommended)
export TF_VAR_proxmox_api_url="https://proxmox:8006"
export TF_VAR_proxmox_api_token_id="user@pam!terraform=secret"
export TF_VAR_proxmox_tls_insecure=true

# Deploy jump server
terraform init
terraform plan
terraform apply

# Get connection info
terraform output ssh_connection

# Connect to jump server
ssh a1@192.168.100.19
```

## Usage

Once deployed, use the jump server to access cluster nodes:

```bash
# SSH to jump server
ssh a1@192.168.100.19

# From jump server, access cluster nodes
ssh a1@192.168.100.10  # Load balancer
ssh a1@192.168.100.11  # Control plane 1
ssh a1@192.168.100.12  # Control plane 2
ssh a1@192.168.100.13  # Control plane 3
ssh a1@192.168.100.14  # Worker 4
ssh a1@192.168.100.15  # Worker 5
ssh a1@192.168.100.16  # Worker 6
```

## Outputs

After deployment, the following outputs are available:

```bash
terraform output
```

- `jump_server_ip`: IP address (192.168.100.19)
- `jump_server_hostname`: Hostname (k8s-jump)
- `jump_server_vm_id`: Proxmox VM ID
- `ssh_connection`: Ready-to-use SSH command

## Customization

Edit [variables.tf](variables.tf) or override via tfvars file:

- `jump_vm_id`: Change VM ID (default: 119)
- `jump_hostname`: Change hostname (default: k8s-jump)
- `jump_ip`: Change IP address (default: 192.168.100.19)
- `template_id`: Use different template (default: 998)

## Destroying

To remove the jump server:

```bash
terraform destroy
```

This will delete the VM from Proxmox. The template and other cluster resources remain untouched.

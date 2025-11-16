# Proxmox Terraform Project

A clean, modular Terraform project for managing Proxmox VMs and LXC containers using the Proxmox API.

## Features

- Modular structure with reusable VM and LXC modules
- Environment-based deployments for multiple projects
- Secure API token authentication
- Support for both VMs (QEMU) and LXC containers
- Extensible configuration with sensible defaults

## Project Structure

```
.
├── main.tf                    # Root module with provider configuration
├── variables.tf               # Global variables
├── outputs.tf                 # Global outputs
├── modules/
│   ├── vm/                    # Reusable VM module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── lxc/                   # Reusable LXC container module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    └── example/               # Example environment (copy for new projects)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

## Getting Started

### Prerequisites

- Terraform >= 1.0
- Proxmox VE server with API access
- API token created in Proxmox

### Creating a Proxmox API Token

1. Log into Proxmox web interface
2. Navigate to Datacenter > Permissions > API Tokens
3. Create a new token for your user (e.g., `user@pam!terraform`)
4. Save the token secret (shown only once)
5. Grant necessary permissions to the token

### Setup

1. Create a new environment:
```bash
cp -r environments/example environments/my-project
cd environments/my-project
```

2. Copy and configure your variables:
```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` with your Proxmox details:
```hcl
proxmox_api_url          = "https://your-proxmox-server:8006/api2/json"
proxmox_api_token_id     = "user@pam!terraform"
proxmox_api_token_secret = "your-secret-token"
proxmox_tls_insecure     = true  # Set to false if using valid certificates
```

4. Initialize Terraform:
```bash
terraform init
```

5. Review the plan:
```bash
terraform plan
```

6. Apply the configuration:
```bash
terraform apply
```

## Usage

### Creating a VM

Use the VM module in your environment's `main.tf`:

```hcl
module "my_vm" {
  source = "../../modules/vm"

  vm_name        = "my-vm"
  target_node    = "pve"
  clone_template = "ubuntu-cloud-template"
  cores          = 2
  memory         = 4096

  disks = [{
    type    = "scsi"
    storage = "local-lvm"
    size    = "20G"
  }]

  networks = [{
    model  = "virtio"
    bridge = "vmbr0"
  }]

  ip_config = "ip=10.0.0.10/24,gw=10.0.0.1"
  tags      = "terraform,production"
}
```

### Creating an LXC Container

Use the LXC module in your environment's `main.tf`:

```hcl
module "my_container" {
  source = "../../modules/lxc"

  hostname    = "my-container"
  target_node = "pve"
  ostemplate  = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  cores       = 2
  memory      = 1024

  networks = [{
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "10.0.0.20/24"
    gateway = "10.0.0.1"
  }]

  nesting = true  # Enable for Docker support
  tags    = "terraform,production"
}
```

## Module Documentation

### VM Module

The VM module supports:
- Cloning from templates
- Custom CPU/memory allocation
- Multiple disks and network interfaces
- Cloud-init configuration
- QEMU guest agent
- Tags and boot settings

See [modules/vm/variables.tf](modules/vm/variables.tf) for all available options.

### LXC Module

The LXC module supports:
- OS template selection
- Resource limits (CPU, memory, swap)
- Network configuration
- SSH key injection
- Nesting support (for Docker)
- Tags and startup settings

See [modules/lxc/variables.tf](modules/lxc/variables.tf) for all available options.

## Best Practices

1. **Separate environments**: Create a new directory under `environments/` for each project
2. **Use version control**: Commit your `.tf` files but not `terraform.tfvars` (contains secrets)
3. **Remote state**: Configure a remote backend for team collaboration
4. **Templates**: Prepare VM templates and LXC templates in Proxmox before deploying
5. **Naming conventions**: Use consistent naming for resources and tags

## Security

- API tokens are marked as sensitive variables
- `terraform.tfvars` is excluded from git via `.gitignore`
- Never commit secrets to version control
- Use appropriate Proxmox permissions for API tokens
- Consider using a secrets manager for production deployments

## Troubleshooting

### Common Issues

1. **TLS certificate errors**: Set `proxmox_tls_insecure = true` for self-signed certificates
2. **Template not found**: Ensure the template exists on the target node
3. **Storage not found**: Verify storage names match your Proxmox configuration
4. **Permission denied**: Check API token permissions in Proxmox

## License

This project structure can be freely used and modified for your needs.

# Grafana Stack LXC Container
# Provides: Grafana, Prometheus, Loki, AlertManager, Proxmox PVE Exporter

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.86.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token_id
  insecure = var.proxmox_tls_insecure
}

# SSH public key for container access
data "local_file" "ssh_public_key" {
  filename = pathexpand("~/.ssh/vm-deb13.pub")
}

# Grafana Stack LXC Container
module "grafana_stack" {
  source = "../../modules/lxc"

  # Basic settings
  hostname    = "grafana-stack"
  target_node = var.target_node
  vmid        = 140

  # OS template
  ostemplate = var.ostemplate

  # Resources (optimized for monitoring stack)
  cores  = 4
  memory = 8192  # 8GB
  swap   = 2048  # 2GB

  # Storage
  rootfs_storage = var.storage_name
  rootfs_size    = "60"

  # Network
  networks = [{
    name    = "eth0"
    bridge  = "vmbr0"
    ip      = "192.168.100.40/24"
    gateway = var.gateway
  }]

  # SSH access
  ssh_public_keys = trimspace(data.local_file.ssh_public_key.content)

  # Features
  nesting = false  # Not needed for monitoring stack

  # Startup
  start_on_boot      = true   # Auto-start monitoring stack
  start_after_create = true

  # Tags
  tags = "lxc,grafana-stack,monitoring"
}

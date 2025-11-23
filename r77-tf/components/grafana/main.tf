# ============================================================================
# Grafana Monitoring Server
# ============================================================================
# This component deploys a dedicated Grafana monitoring VM with Prometheus
# and Loki for multi-platform infrastructure monitoring (K8s, AWS, DO).

terraform {
  required_version = ">= 1.0.0"

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

# Provider configuration
provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token_id
  insecure  = var.proxmox_tls_insecure

  ssh {
    agent = true
  }
}

# SSH public key for VM access
data "local_file" "ssh_public_key" {
  filename = pathexpand("~/.ssh/vm-deb13.pub")
}

# ============================================================================
# Grafana Monitoring VM
# ============================================================================

module "grafana" {
  source = "../../modules/vm"

  # VM identification
  vm_name        = var.grafana_hostname
  target_node    = var.proxmox_node
  vmid           = var.grafana_vm_id
  clone_template = var.template_id
  full_clone     = true

  # Resources (moderate configuration for Grafana + Prometheus + Loki)
  cores  = 4
  memory = 4096  # 4GB in MB

  # Disk configuration
  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = 80  # 60GB for Grafana, Prometheus, and Loki data
    file_format  = "raw"
  }]

  # Network configuration
  networks = [{
    model  = "virtio"
    bridge = var.network_bridge
  }]

  # Cloud-init configuration
  enable_cloud_init = true
  ip_address        = "${var.grafana_ip}/24"
  gateway           = var.gateway
  dns_servers       = var.dns_servers

  # Cloud-init user configuration
  ci_user  = var.cloud_init_user
  ssh_keys = [trimspace(data.local_file.ssh_public_key.content)]

  # Settings
  start_on_boot = true
  tags          = "monitoring,grafana"
}

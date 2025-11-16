terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.86.0"
    }
  }
}

# ============================================================================
# Provider Configuration
# ============================================================================
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token_id
  insecure  = var.proxmox_tls_insecure
}

# ============================================================================
# Data Sources
# ============================================================================
data "local_file" "ssh_public_key" {
  filename = "${path.root}/../../keys/vm-deb13.pub"
}

# ============================================================================
# Jump Server VM
# ============================================================================
module "k8s_jump" {
  source = "../../modules/vm"

  # VM identification
  vm_name        = var.jump_hostname
  target_node    = var.proxmox_node
  vmid           = var.jump_vm_id
  clone_template = var.template_id
  full_clone     = true

  # Resources (lightweight configuration)
  cores  = 1
  memory = 1024  # 1GB in MB

  # Disk configuration
  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = 8  # 8GB
    file_format  = "raw"
  }]

  # Network configuration
  networks = [{
    model  = "virtio"
    bridge = var.network_bridge
  }]

  # Cloud-init configuration
  enable_cloud_init = true
  ip_address        = "${var.jump_ip}/24"
  gateway           = var.gateway
  dns_servers       = var.dns_servers

  # Cloud-init user configuration
  ci_user  = var.cloud_init_user
  ssh_keys = [trimspace(data.local_file.ssh_public_key.content)]

  # Settings
  start_on_boot = true
  tags          = "tf,k8s,jump-server"
}

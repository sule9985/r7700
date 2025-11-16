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
# RANCHER Server VM
# ============================================================================
module "k8s_rancher" {
  source = "../../modules/vm"

  # VM identification
  vm_name        = var.rancher_hostname
  target_node    = var.proxmox_node
  vmid           = var.rancher_vm_id
  clone_template = var.template_id
  full_clone     = true

  # Resources (configuration)
  cores  = 4
  memory = 6144

  # Disk configuration
  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = 60
    file_format  = "raw"
  }]

  # Network configuration
  networks = [{
    model  = "virtio"
    bridge = var.network_bridge
  }]

  # Cloud-init configuration
  enable_cloud_init = true
  ip_address        = "${var.rancher_ip}/24"
  gateway           = var.gateway
  dns_servers       = var.dns_servers

  # Cloud-init user configuration
  ci_user  = var.cloud_init_user
  ssh_keys = [trimspace(data.local_file.ssh_public_key.content)]

  # Settings
  start_on_boot = true
  tags          = "tf,k8s,rancher"
}

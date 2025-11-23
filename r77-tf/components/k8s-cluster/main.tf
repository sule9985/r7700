# Kubernetes Cluster Environment
# This environment creates a K8s cluster with load balancer

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.86"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
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

# Load Balancer VM for Kubernetes API
module "k8s_lb" {
  source = "../../modules/vm"

  # VM identification
  vm_name        = "k8s-lb"
  target_node    = var.proxmox_node
  vmid           = 110
  clone_template = 998
  full_clone     = true

  # Resources
  cores  = 2
  memory = 1024

  # Disk configuration (15GB)
  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = 15
    file_format  = "raw"
  }]

  # Network configuration
  networks = [{
    model  = "virtio"
    bridge = "vmbr0"
  }]

  # Cloud-init configuration
  enable_cloud_init = true
  ip_address        = "${var.k8s_lb_ip}/24"
  gateway           = var.gateway
  dns_servers       = var.dns_servers

  # Cloud-init user configuration
  ci_user  = var.vm_user
  ssh_keys = [trimspace(data.local_file.ssh_public_key.content)]

  # Settings
  start_on_boot = true

  tags = "tf,k8s,load-balancer"
}

# K8S Control Planes (dynamic)
module "k8s_control_planes" {
  source   = "../../modules/vm"
  for_each = var.control_plane_nodes

  vm_name        = each.key
  vmid           = each.value.vmid
  target_node    = var.proxmox_node
  clone_template = 998
  full_clone     = true
  
  cores  = 2
  memory = each.value.memory
  
  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = each.value.disk
    file_format  = "raw"
  }]
  
  networks = [{ model = "virtio", bridge = "vmbr0" }]
  
  enable_cloud_init = true
  ip_address        = "${each.value.ip}/24"
  gateway           = var.gateway
  dns_servers       = var.dns_servers
  ci_user           = var.vm_user
  ssh_keys          = [trimspace(data.local_file.ssh_public_key.content)]
  start_on_boot     = true
  tags              = "tf,k8s,control-plane"
}

# K8S Workers (dynamic)
module "k8s_workers" {
  source   = "../../modules/vm"
  for_each = var.worker_nodes

  vm_name        = each.key
  vmid           = each.value.vmid
  target_node    = var.proxmox_node
  clone_template = 998
  full_clone     = true
  
  cores  = 2
  memory = each.value.memory
  
  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = each.value.disk
    file_format  = "raw"
  }]
  
  networks = [{ model = "virtio", bridge = "vmbr0" }]
  
  enable_cloud_init = true
  ip_address        = "${each.value.ip}/24"
  gateway           = var.gateway
  dns_servers       = var.dns_servers
  ci_user           = var.vm_user
  ssh_keys          = [trimspace(data.local_file.ssh_public_key.content)]
  start_on_boot     = true
  tags              = "tf,k8s,worker"
}

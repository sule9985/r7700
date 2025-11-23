# ============================================================================
# JMeter Load Testing Server
# ============================================================================
# This component deploys a dedicated JMeter VM for performance testing
# - Non-GUI (headless) JMeter execution
# - Load testing for web applications, APIs, databases
# - Integration with Grafana for real-time monitoring

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
# JMeter Load Testing VM
# ============================================================================

module "jmeter" {
  source = "../../modules/vm"

  # VM identification
  vm_name        = var.jmeter_hostname
  target_node    = var.proxmox_node
  vmid           = var.jmeter_vm_id
  clone_template = var.template_id
  full_clone     = true

  # Resources (upgraded for 5000 concurrent users)
  cores  = 16
  memory = 32768  # 32GB in MB

  # Disk configuration
  disks = [{
    interface    = "scsi0"
    datastore_id = var.storage_name
    size         = 80  # 80GB for JMeter, test plans, and large-scale test results
    file_format  = "raw"
  }]

  # Network configuration
  networks = [{
    model  = "virtio"
    bridge = var.network_bridge
  }]

  # Cloud-init configuration
  enable_cloud_init = true
  ip_address        = "${var.jmeter_ip}/24"
  gateway           = var.gateway
  dns_servers       = var.dns_servers

  # Cloud-init user configuration
  ci_user  = var.cloud_init_user
  ssh_keys = [trimspace(data.local_file.ssh_public_key.content)]

  # Settings
  start_on_boot = false
  tags          = "testing,jmeter"
}

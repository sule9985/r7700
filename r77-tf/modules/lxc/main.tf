terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_container" "container" {
  node_name = var.target_node
  vm_id     = var.vmid

  # Operating system
  operating_system {
    template_file_id = var.ostemplate
    type             = "unmanaged"
  }

  # Unprivileged container
  unprivileged = var.unprivileged

  # CPU
  cpu {
    cores = var.cores
  }

  # Memory
  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  # Root filesystem
  disk {
    datastore_id = var.rootfs_storage
    size         = var.rootfs_size
  }

  # Network interfaces
  dynamic "network_interface" {
    for_each = var.networks
    content {
      name    = network_interface.value.name
      bridge  = network_interface.value.bridge
      enabled = true
      vlan_id = lookup(network_interface.value, "vlan_id", null)
    }
  }

  # Initialization
  initialization {
    hostname = var.hostname

    # IP configuration
    dynamic "ip_config" {
      for_each = var.networks
      content {
        ipv4 {
          address = ip_config.value.ip == "dhcp" ? "dhcp" : ip_config.value.ip
          gateway = lookup(ip_config.value, "gateway", null)
        }
      }
    }

    # SSH keys
    user_account {
      keys = var.ssh_public_keys != "" ? [var.ssh_public_keys] : []
    }
  }

  # Features
  features {
    nesting = var.nesting
  }

  # Lifecycle
  started = var.start_after_create
  on_boot = var.start_on_boot

  tags = var.tags != "" ? split(",", var.tags) : []
}

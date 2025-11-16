terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.82"  # VE 9 compatible
    }
  }
}

data "local_file" "ssh_public_key" {
  filename = "../../keys/vm-deb13.pub"
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  node_name   = var.target_node
  vm_id       = var.vmid
  description = var.description

  # === CLONE FROM TEMPLATE (NEW: Key for your workflow) ===
  clone {
    vm_id      = var.clone_template  # Template VMID (e.g., 999)
    full       = var.full_clone      # true = independent copy
    datastore_id = var.disks[0].datastore_id  # Target storage (e.g., local-zfs)
    # Terraform auto-resizes during clone if size differs
  }

  # === CPU ===
  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = "host"  # Best for performance
  }

  # === MEMORY ===
  memory {
    dedicated = var.memory
  }

  # === QEMU AGENT ===
  agent {
    enabled = true
  }

  # === DISKS (with resize support) ===
  dynamic "disk" {
    for_each = var.disks
    content {
      interface    = disk.value.interface
      datastore_id = disk.value.datastore_id  # local-zfs
      size         = disk.value.size          # e.g., 40 (resizes from template's 3)
      file_format  = lookup(disk.value, "file_format", "raw")  # ZFS-optimized
      iothread     = true
      ssd          = true  # TRIM support
    }
  }

  # === NETWORK ===
  dynamic "network_device" {
    for_each = var.networks
    content {
      model   = network_device.value.model
      bridge  = network_device.value.bridge
      vlan_id = lookup(network_device.value, "vlan_id", null)
    }
  }

  # === CLOUD-INIT (Static IP, SSH, User) ===
  dynamic "initialization" {
    for_each = var.enable_cloud_init ? [1] : []
    content {
      datastore_id = var.cloudinit_datastore_id

      ip_config {
        ipv4 {
          address = var.ip_address  # e.g., 192.168.100.50/24
          gateway = var.gateway     # e.g., 192.168.100.1
        }
      }
      dns {
        servers = var.dns_servers
        domain  = var.dns_domain
      }
      user_account {
        username = var.ci_user     # e.g., admin
        password = var.ci_password # Optional (use SSH keys)
        keys     = var.ssh_keys    # List of pubkeys
      }
    }
  }

  # === BOOT & LIFECYCLE ===
  startup {
    order    = "1"
    up_delay = 60  # Wait for cloud-init
  }
  on_boot  = var.start_on_boot
  started  = true

  # === TAGS ===
  tags = var.tags != "" ? split(",", var.tags) : []

  # === LIFECYCLE ===
  lifecycle {
    ignore_changes = [
      # Ignore cloud-init changes (regenerates on apply)
      initialization,
    ]
  }
}

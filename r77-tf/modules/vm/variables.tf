variable "enable_cloud_init" {
  type        = bool
  default     = true
  description = "Enable cloud-init configuration"
}

variable "gateway" {
  type        = string
  default     = "192.168.100.3"
  description = "Gateway IP"
}

variable "dns_servers" {
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "dns_domain" {
  type        = string
  default     = ""
}

variable "ci_user" {
  type        = string
  default     = "admin"
}

variable "ci_password" {
  type        = string
  default     = "a1s2d3"  # Leave empty for SSH-only
  sensitive   = true
}

variable "ssh_keys" {
  type        = list(string)
  default     = []  # e.g., [file("~/.ssh/id_rsa.pub")]
  description = "List of SSH public keys"
}

# Your existing vars (cores, disks, etc.)...
variable "disks" {
  type = list(object({
    interface     = string
    datastore_id  = string
    size          = number
    file_format   = optional(string, "raw")
  }))
  default = [
    {
      interface    = "scsi0"
      datastore_id = "local-zfs"
      size         = 40  # Resizes template
    }
  ]
}

variable "networks" {
  type = list(object({
    model   = string
    bridge  = string
    vlan_id = optional(number)
  }))
  default = [
    {
      model  = "virtio"
      bridge = "vmbr0"
    }
  ]
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "target_node" {
  description = "Target Proxmox node"
  type        = string
}

variable "vmid" {
  description = "VM ID (optional, auto-assigned if not specified)"
  type        = number
  default     = null
}

variable "description" {
  description = "VM description"
  type        = string
  default     = ""
}

variable "clone_template" {
  description = "Template VM ID to clone from"
  type        = number
  default     = null
}

variable "full_clone" {
  description = "Whether to create a full clone"
  type        = bool
  default     = true
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "ip_config" {
  description = "Whether to configure IP (leave empty to skip cloud-init)"
  type        = string
  default     = ""
}

variable "ip_address" {
  description = "IP address with CIDR (e.g., '192.168.1.100/24' or 'dhcp')"
  type        = string
  default     = "dhcp"
}

variable "start_on_boot" {
  description = "Start VM on Proxmox boot"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the VM (comma-separated)"
  type        = string
  default     = ""
}

variable "cloudinit_datastore_id" {
  description = "Datastore ID for CloudInit drive"
  type        = string
  default     = "local-zfs"
}

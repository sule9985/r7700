variable "hostname" {
  description = "Hostname of the LXC container"
  type        = string
}

variable "target_node" {
  description = "Target Proxmox node"
  type        = string
}

variable "vmid" {
  description = "Container ID (optional, auto-assigned if not specified)"
  type        = number
  default     = null
}

variable "ostemplate" {
  description = "OS template to use (e.g., 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst')"
  type        = string
}

variable "unprivileged" {
  description = "Create unprivileged container"
  type        = bool
  default     = true
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 512
}

variable "swap" {
  description = "Swap in MB"
  type        = number
  default     = 512
}

variable "rootfs_storage" {
  description = "Storage for root filesystem"
  type        = string
  default     = "local-lvm"
}

variable "rootfs_size" {
  description = "Size of root filesystem (e.g., '8G')"
  type        = string
  default     = "8G"
}

variable "networks" {
  description = "List of network interfaces"
  type = list(object({
    name     = string
    bridge   = string
    ip       = string
    gateway  = optional(string)
    vlan_id  = optional(number)
  }))
  default = [{
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }]
}

variable "ssh_public_keys" {
  description = "SSH public keys to add to the container"
  type        = string
  default     = ""
}

variable "nesting" {
  description = "Enable nesting (required for Docker)"
  type        = bool
  default     = false
}

variable "start_on_boot" {
  description = "Start container on Proxmox boot"
  type        = bool
  default     = false
}

variable "start_after_create" {
  description = "Start container immediately after creation"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the container"
  type        = string
  default     = ""
}

# Proxmox connection configuration
variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://proxmox.example.com:8006)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token in format: user@pam!token_name=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (use true for self-signed certificates)"
  type        = bool
  default     = true
}

# Proxmox node configuration
variable "proxmox_node" {
  description = "Target Proxmox node name"
  type        = string
  default     = "pve"
}

variable "storage_name" {
  description = "Storage name for VM disks"
  type        = string
  default     = "local-zfs"
}

# Network configuration (uses global defaults from root, can be overridden)
variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.100.1"
}

variable "dns_servers" {
  description = "DNS nameservers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# Load Balancer configuration
variable "k8s_lb_ip" {
  description = "IP address for K8s load balancer"
  type        = string
  default     = "192.168.100.10"
}

variable "control_plane_nodes" {
  description = "K8s control plane node configurations"
  type = map(object({
    vmid   = number
    ip     = string
    memory = number
    disk   = number
  }))
  default = {
    "k8s-cp1" = { vmid = 111, ip = "192.168.100.11", memory = 4096, disk = 50 }
    "k8s-cp2" = { vmid = 112, ip = "192.168.100.12", memory = 4096, disk = 50 }
    "k8s-cp3" = { vmid = 113, ip = "192.168.100.13", memory = 4096, disk = 50 }
  }
}

variable "worker_nodes" {
  description = "K8s worker node configurations"
  type = map(object({
    vmid   = number
    ip     = string
    memory = number
    disk   = number
  }))
  default = {
    "k8s-worker4" = { vmid = 114, ip = "192.168.100.14", memory = 4096, disk = 50 }
    "k8s-worker5" = { vmid = 115, ip = "192.168.100.15", memory = 4096, disk = 50 }
    "k8s-worker6" = { vmid = 116, ip = "192.168.100.16", memory = 4096, disk = 50 }
  }
}

# Cloud-init user configuration
variable "vm_user" {
  description = "Default user for VMs (cloud-init)"
  type        = string
  default     = "a1"
}

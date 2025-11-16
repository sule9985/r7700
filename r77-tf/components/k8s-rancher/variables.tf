# ============================================================================
# Proxmox Provider Configuration
# ============================================================================
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token (format: user@pam!token=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (use true for self-signed certificates)"
  type        = bool
  default     = true
}

# ============================================================================
# Proxmox Node Configuration
# ============================================================================
variable "proxmox_node" {
  description = "Proxmox node where VMs will be created"
  type        = string
  default     = "pve"
}

variable "storage_name" {
  description = "Storage name for VM disks"
  type        = string
  default     = "local-zfs"
}

# ============================================================================
# Template Configuration
# ============================================================================
variable "template_id" {
  description = "Template VM ID to clone from (e.g., 998 or 999)"
  type        = number
  default     = 998
}

# ============================================================================
# RANCHER Server Configuration
# ============================================================================
variable "rancher_vm_id" {
  description = "VM ID for RANCHER server"
  type        = number
  default     = 119
}

variable "rancher_hostname" {
  description = "Hostname for RANCHER server"
  type        = string
  default     = "k8s-jump"
}

variable "rancher_ip" {
  description = "IP address for RANCHER server (without CIDR)"
  type        = string
  default     = "192.168.100.20"
}

# ============================================================================
# Network Configuration
# ============================================================================
variable "network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "192.168.100.3"
}

variable "dns_servers" {
  description = "DNS nameservers for VMs"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# ============================================================================
# Cloud-init User Configuration
# ============================================================================
variable "cloud_init_user" {
  description = "Cloud-init default user"
  type        = string
  default     = "a1"
}

variable "cloud_init_password" {
  description = "Cloud-init user password (optional, leave empty to disable password auth)"
  type        = string
  default     = ""
  sensitive   = true
}

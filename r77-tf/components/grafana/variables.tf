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
# Infrastructure Variables
# ============================================================================

variable "proxmox_node" {
  description = "Proxmox node name to deploy VMs on"
  type        = string
  default     = "pve"
}

variable "storage_name" {
  description = "Proxmox storage name for VM disks"
  type        = string
  default     = "local-zfs"
}

variable "template_id" {
  description = "VMID of the Debian 13 cloud-init template"
  type        = number
  default     = 998
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

# ============================================================================
# Network Variables
# ============================================================================

variable "gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "192.168.100.3"
}

variable "dns_servers" {
  description = "DNS servers for VMs"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# ============================================================================
# Grafana VM Variables
# ============================================================================

variable "grafana_vm_id" {
  description = "VMID for Grafana monitoring server"
  type        = number
  default     = 121
}

variable "grafana_hostname" {
  description = "Hostname for Grafana VM"
  type        = string
  default     = "grafana"
}

variable "grafana_ip" {
  description = "IP address for Grafana VM (without CIDR)"
  type        = string
  default     = "192.168.100.21"
}

# ============================================================================
# Cloud-init Variables
# ============================================================================

variable "cloud_init_user" {
  description = "Default user created by cloud-init"
  type        = string
  default     = "a1"
}

# Proxmox connection variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (format: user@pam!token=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (for self-signed certificates)"
  type        = bool
  default     = true
}

# Infrastructure variables
variable "target_node" {
  description = "Proxmox node to deploy to"
  type        = string
  default     = "pve"
}

variable "storage_name" {
  description = "Storage pool name for LXC rootfs"
  type        = string
  default     = "local-zfs"
}

variable "ostemplate" {
  description = "LXC OS template"
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.100.1"
}

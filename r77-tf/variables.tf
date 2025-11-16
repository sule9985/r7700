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

# Global network configuration
variable "gateway" {
  description = "Default network gateway for all environments"
  type        = string
  default     = "192.168.100.3"
}

variable "dns_servers" {
  description = "Default DNS nameservers for all environments"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

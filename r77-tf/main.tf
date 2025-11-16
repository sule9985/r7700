terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.86.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token_id
  insecure  = var.proxmox_tls_insecure

  ssh {
    agent = true
  }
}

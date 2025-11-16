# ============================================================================
# Jump Server Outputs
# ============================================================================
output "jump_server_ip" {
  description = "IP address of the jump server"
  value       = var.jump_ip
}

output "jump_server_hostname" {
  description = "Hostname of the jump server"
  value       = var.jump_hostname
}

output "jump_server_vm_id" {
  description = "VM ID of the jump server"
  value       = var.jump_vm_id
}

output "ssh_connection" {
  description = "SSH connection command for jump server"
  value       = "ssh ${var.cloud_init_user}@${var.jump_ip}"
}

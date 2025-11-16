output "container_id" {
  description = "ID of the created container"
  value       = proxmox_virtual_environment_container.container.id
}

output "container_hostname" {
  description = "Hostname of the created container"
  value       = proxmox_virtual_environment_container.container.initialization[0].hostname
}

output "vm_id" {
  description = "ID of the created VM"
  value       = proxmox_virtual_environment_vm.vm.id
}

output "vm_name" {
  description = "Name of the created VM"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "vm_ipv4_addresses" {
  description = "IPv4 addresses of the VM"
  value       = try(proxmox_virtual_environment_vm.vm.ipv4_addresses, [])
}

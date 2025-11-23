# ============================================================================
# Grafana Component Outputs
# ============================================================================

output "grafana_vm_id" {
  description = "VMID of the Grafana monitoring server"
  value       = module.grafana.vm_id
}

output "grafana_hostname" {
  description = "Hostname of the Grafana monitoring server"
  value       = var.grafana_hostname
}

output "grafana_ip" {
  description = "IP address of the Grafana monitoring server"
  value       = var.grafana_ip
}

output "grafana_ssh_command" {
  description = "SSH command to access Grafana server"
  value       = "ssh ${var.cloud_init_user}@${var.grafana_ip}"
}

output "grafana_web_ui" {
  description = "Grafana web interface URL"
  value       = "http://${var.grafana_ip}:3000"
}

output "prometheus_ui" {
  description = "Prometheus web interface URL"
  value       = "http://${var.grafana_ip}:9090"
}

output "summary" {
  description = "Summary of deployed Grafana infrastructure"
  value = {
    vmid        = module.grafana.vm_id
    hostname    = var.grafana_hostname
    ip_address  = var.grafana_ip
    ssh_command = "ssh ${var.cloud_init_user}@${var.grafana_ip}"
    grafana_url = "http://${var.grafana_ip}:3000"
    prometheus_url = "http://${var.grafana_ip}:9090"
  }
}

# ============================================================================
# JMeter Component Outputs
# ============================================================================

output "jmeter_vm_id" {
  description = "VMID of the JMeter load testing server"
  value       = module.jmeter.vm_id
}

output "jmeter_hostname" {
  description = "Hostname of the JMeter load testing server"
  value       = var.jmeter_hostname
}

output "jmeter_ip" {
  description = "IP address of the JMeter load testing server"
  value       = var.jmeter_ip
}

output "jmeter_ssh_command" {
  description = "SSH command to access JMeter server"
  value       = "ssh ${var.cloud_init_user}@${var.jmeter_ip}"
}

output "jmeter_metrics_endpoint" {
  description = "Prometheus metrics endpoint (if JMeter Prometheus plugin enabled)"
  value       = "http://${var.jmeter_ip}:9270/metrics"
}

output "summary" {
  description = "Summary of deployed JMeter infrastructure"
  value = {
    vmid              = module.jmeter.vm_id
    hostname          = var.jmeter_hostname
    ip_address        = var.jmeter_ip
    ssh_command       = "ssh ${var.cloud_init_user}@${var.jmeter_ip}"
    metrics_endpoint  = "http://${var.jmeter_ip}:9270/metrics"
  }
}

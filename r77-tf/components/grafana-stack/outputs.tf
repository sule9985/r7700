output "container_id" {
  description = "Grafana Stack LXC container ID"
  value       = module.grafana_stack.container_id
}

output "container_hostname" {
  description = "Grafana Stack hostname"
  value       = module.grafana_stack.container_hostname
}

output "container_ip" {
  description = "Grafana Stack IP address"
  value       = "192.168.100.40"
}

output "grafana_url" {
  description = "Grafana web UI URL"
  value       = "http://192.168.100.40:3000"
}

output "prometheus_url" {
  description = "Prometheus web UI URL"
  value       = "http://192.168.100.40:9090"
}

output "alertmanager_url" {
  description = "AlertManager web UI URL"
  value       = "http://192.168.100.40:9093"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh root@192.168.100.40"
}

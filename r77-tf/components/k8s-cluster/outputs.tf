# Load Balancer outputs
output "k8s_lb_id" {
  description = "VM ID of the K8s load balancer"
  value       = module.k8s_lb.vm_id
}

output "k8s_lb_name" {
  description = "VM name of the K8s load balancer"
  value       = module.k8s_lb.vm_name
}

output "k8s_lb_ip" {
  description = "IP address of the K8s load balancer"
  value       = var.k8s_lb_ip
}

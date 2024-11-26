
output "master_node_ip" {
  description = "The IP address of the Kubernetes master node"
  value       = "${var.k8s_ip_nw}${var.master_ip_start}"
}

output "worker_node_ips" {
  description = "The IP addresses of the Kubernetes worker nodes"
  value       = [for i in range(var.num_worker_nodes) : "${var.k8s_ip_nw}${var.worker_ip_start + i}"]
}

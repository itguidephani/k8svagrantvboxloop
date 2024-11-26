
variable "num_worker_nodes" {
  description = "Number of Kubernetes worker nodes"
  default     = 2
}

variable "k8s_ip_nw" {
  description = "Base IP for the Kubernetes network"
  default     = "192.168.10."
}

variable "master_ip_start" {
  description = "Starting IP address for the master node"
  default     = 10
}

variable "worker_ip_start" {
  description = "Starting IP address for the worker nodes"
  default     = 20
}

variable "k8master_hostname" {
  description = "Hostname for the Kubernetes master node"
  default     = "k8scpmaster01"
}
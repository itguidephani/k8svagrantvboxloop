
provider "virtualbox" {}

# Import variables
variable "num_worker_nodes" {}
variable "k8s_ip_nw" {}
variable "master_ip_start" {}
variable "worker_ip_start" {}
variable "k8master_hostname" {}

# Kubernetes Master Node
resource "virtualbox_vm" "k8s_master" {
  name     = var.k8master_hostname
  memory   = 3072
  cpus     = 4
  image    = "ubuntu/jammy64"
  hostname = var.k8master_hostname

  network_adapter {
    type             = "hostonly"
    hostonly_adapter = "vboxnet0"
    ipv4_address     = "${var.k8s_ip_nw}${var.master_ip_start}"
    ipv4_netmask     = "255.255.255.0"
  }

  provisioner "remote-exec" {
    inline = [
      "NODE_IP=$(ip -o -4 addr show | grep \"${var.k8s_ip_nw}\" | awk '{print $4}' | awk -F/ '{print $1}')",
      "sudo sed -i -E 's|^KUBELET_EXTRA_ARGS=.*|KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}|' /etc/default/kubelet",
      "sudo kubeadm init --apiserver-advertise-address=${var.k8s_ip_nw}${var.master_ip_start} --control-plane-endpoint=${var.k8s_ip_nw}${var.master_ip_start} --node-name=${var.k8master_hostname} --ignore-preflight-errors=Swap",
      "sudo kubeadm config images pull"
    ]
  }
}

# Kubernetes Worker Nodes
resource "virtualbox_vm" "k8s_worker" {
  count    = var.num_worker_nodes
  name     = "k8sworker${count.index + 1}"
  memory   = 3072
  cpus     = 4
  image    = "ubuntu/jammy64"
  hostname = "k8sworker${count.index + 1}"

  network_adapter {
    type             = "hostonly"
    hostonly_adapter = "vboxnet0"
    ipv4_address     = "${var.k8s_ip_nw}${var.worker_ip_start + count.index}"
    ipv4_netmask     = "255.255.255.0"
  }

  provisioner "remote-exec" {
    inline = [
      "NODE_IP=$(ip -o -4 addr show | grep \"${var.k8s_ip_nw}\" | awk '{print $4}' | awk -F/ '{print $1}')",
      "sudo sed -i -E 's|^KUBELET_EXTRA_ARGS=.*|KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}|' /etc/default/kubelet"
    ]
  }
}

# Shared Provisioning Script
resource "local_file" "shared_provision_script" {
  filename = "scripts/kubernets_manage.sh"
  content  = file("scripts/kubernets_manage.sh")
}

resource "null_resource" "shared_provisioning" {
  provisioner "local-exec" {
    command = <<EOC
      sudo apt-get update
      sudo apt-get install -y dos2unix net-tools
      sudo dos2unix ./scripts/kubernets_manage.sh
      bash -x ./scripts/kubernets_manage.sh
    EOC
  }
}
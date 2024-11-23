#!/bin/bash

export KUBECTLVER='v1.31'
export INSTALLURL_DEB="https://pkgs.k8s.io/core:/stable:/${KUBECTLVER}/deb"
export APTKY_DEB_K8='/etc/apt/keyrings/kubernetes-apt-keyring.gpg'
export DEBREPO="/etc/apt/sources.list.d/kubernetes.list"

# export HELM_INSTALLURL='https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3'

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Containerd installation script"
echo "Instructions from https://kubernetes.io/docs/setup/production-environment/container-runtimes/"

curl -fsSL $INSTALLURL_DEB/Release.key | sudo gpg --dearmor -o $APTKY_DEB_K8
echo "deb [signed-by=${APTKY_DEB_K8}] ${INSTALLURL_DEB}/ /" | sudo tee $DEBREPO

echo "Creating containerd configuration file with list of necessary modules that need to be loaded with containerd"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

echo "Load containerd modules"
sudo modprobe overlay
sudo modprobe br_netfilter

echo "Creates configuration file for kubernetes-cri file (changed to k8s.conf)"
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

echo "Applying sysctl params"
sudo sysctl --system

echo "Verify that the br_netfilter, overlay modules are loaded by running the following commands:"
lsmod | grep br_netfilter
lsmod | grep overlay

echo "Verify that the net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables, and net.ipv4.ip_forward system variables are set to 1 in your sysctl config by running the following command:"
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

sudo apt-get clean all

echo "Update packages list"
sudo apt-get update

echo "Install containerd"
sudo apt-get -y install containerd apt-transport-https ca-certificates curl gpg jq kubelet kubeadm kubectl

echo "Create a default config file at default location"
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl disable apparmor; sudo systemctl stop apparmor
echo "Restarting containerd"
sudo systemctl daemon-reload
sudo systemctl restart containerd kubelet
sudo systemctl enable containerd kubelet
sudo apt-mark hold kubelet kubeadm kubectl
#
echo "Installing helm packager"
# sudo curl $HELM_INSTALLURL | bash
sudo snap install helm --classic
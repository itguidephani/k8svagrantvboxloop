#!/bin/bash
set -e

## Check if an argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <master|worker>"
    exit 1
fi

ROLE=$1
# RUNUSER01=`echo $USER`
RUNUSER01=vagrant

#if [ "$ROLE" == "master" ]; then
#    install_packages
#    install_kube
#    echo "Initializing Kubernetes master..."
#    kubeadm init --pod-network-cidr=192.168.0.0/16
#    echo "Setting up kubeconfig..."
#    mkdir -p $HOME/.kube
#    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#    chown $(id -u):$(id -g) $HOME/.kube/config
#    echo "Kubernetes master installed successfully."
#    # Install a network plugin (Weave Net in this case)
#    kubectl apply -f https://git.io/weave-kube-1.12

#elif [ "$ROLE" == "worker" ]; then
#    install_packages
#   # install_kube
#    echo "Kubernetes worker node installed successfully."
#    echo "Please join the worker node to the cluster using the command provided by the master node (kubeadm join ...)."
#
#else
#    echo "Invalid argument. Please specify 'master' or 'worker'."
#    exit 1
#fi


HOSTNAME=$(hostname)
#export KUBECTLVER='v1.30'
#export INSTALLURL="https://pkgs.k8s.io/core:/stable:/${KUBECTLVER}/deb"
#export APTKY='/etc/apt/keyrings/kubernetes-apt-keyring.gpg'
#export REPO='/etc/apt/sources.list.d/kubernetes.list'

# Install necessary packages
install_packages() {
    echo "Updating package list..."
    sudo apt-get update &>/dev/null
    echo "Installing required packages..."
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg net-tools &>/dev/null
}

install_kube() {
    echo "Installing Kubernetes..."
    sudo apt-get update
	sudo apt-get install -y docker.io
	# if ! getent group docker > /dev/null 2>&1; then sudo groupadd docker; fi
	sudo swapoff -a
		
	curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
	sudo apt-get update
	sudo apt-get install -y kubelet kubeadm kubectl
	sudo apt-mark hold kubelet kubeadm kubectl
	sudo systemctl enable kubelet
	sudo systemctl enable --now docker
	sudo usermod -aG docker $RUNUSER01

 }

install_packages
install_kube


## Check if an argument is provided
# if [ "$#" -ne 1 ]; then
#    echo "Usage: $0 <master|worker>"
#    exit 1
# fi


#if [ "$ROLE" == "master" ]; then
#    install_packages
#    install_kube
#    echo "Initializing Kubernetes master..."
#    kubeadm init --pod-network-cidr=192.168.0.0/16
#    echo "Setting up kubeconfig..."
#    mkdir -p $HOME/.kube
#    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#    chown $(id -u):$(id -g) $HOME/.kube/config
#    echo "Kubernetes master installed successfully."
#    # Install a network plugin (Weave Net in this case)
#    kubectl apply -f https://git.io/weave-kube-1.12

#elif [ "$ROLE" == "worker" ]; then
#    install_packages
#   # install_kube
#    echo "Kubernetes worker node installed successfully."
#    echo "Please join the worker node to the cluster using the command provided by the master node (kubeadm join ...)."
#
#else
#    echo "Invalid argument. Please specify 'master' or 'worker'."
#    exit 1
#fi

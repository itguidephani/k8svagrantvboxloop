#!/bin/bash

###  K8S Cluster ####
export k8s_modules01="overlay br_netfilter"
export k8s_kernel_nw01="net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables"

export KUBECTLVER='v1.31'
export INSTALLURL_DEB="https://pkgs.k8s.io/core:/stable:/${KUBECTLVER}/deb"
export APTKY_DEB_K8='/etc/apt/keyrings/kubernetes-apt-keyring.gpg'
export DEBREPO="/etc/apt/sources.list.d/kubernetes.list"

export SYSTMD='sudo systemctl'
export DISABLE_DAEMON='apparmor'
export ENABLE_DAEMON='containerd kubelet'

export APTGET='sudo apt'
export REQ_PPK='apt-transport-https ca-certificates curl gpg jq'

export KUBE_PKG='containerd jq kubelet kubeadm kubectl'

### END K8S Cluster ####

# export HELM_INSTALLURL='https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3'

SwapOF(){
    swap_status=$(swapon --noheadings)	if [ -z "$swap_status" ]; then  echo "Swap memory is OFF."; else sudo swapoff -a; sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab; sudo sudo (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true; fi
 }

SwapOF

echo "Containerd installation script"
echo "Instructions from https://kubernetes.io/docs/setup/production-environment/container-runtimes/"

curl -fsSL $INSTALLURL_DEB/Release.key | sudo gpg --dearmor -o $APTKY_DEB_K8
echo "deb [signed-by=${APTKY_DEB_K8}] ${INSTALLURL_DEB}/ /" | sudo tee $DEBREPO

echo "Creating containerd configuration file with list of necessary modules that need to be loaded with containerd"
KernelContainerD_Modules(){
   for LoMD in $(echo $k8s_modules01); do
			if lsmod | grep -q "^${LoMD} "; then
				echo "The module '${LoMD}' is already loaded."
			else
				echo "${LoMD}" | sudo tee -a /etc/modules-load.d/k8s_modules.conf > /dev/null
				sudo modprobe "${LoMD}"
				if lsmod | grep -q "^${LoMD} "; then
					echo "The module '${LoMD}' is already loaded."
				fi
			fi
	done
 }

KernelContainerD_Modules

K8sNW_KERNL_Parameters(){
	for NeTWPAM in $(echo $k8s_kernel_nw01); do
			if sudo sysctl -a | grep -wq "^${NeTWPAM} "; then
				echo "The kernel parameters'${NeTWPAM}' is loaded."
			else
				sudo echo $NeTWPAM >> /etc/sysctl.d/kubernetes.conf
				sudo sysctl --system &>/dev/null
				echo "Verify that the $k8s_kernel_nw01 system variables are set to 1 in your sysctl config by running the following command:"
				sysctl $k8s_kernel_nw01

			fi
	done
 }

K8sNW_KERNL_Parameters

$APTGET clean all
echo "Update packages list"
$APTGET update
echo "Install containerd"
$APTGET -y install $REQ_PPK $KUBE_PKG

containerdCGroup_Driver(){
	if [ ! -f /etc/containerd/config.toml ]; then
			sudo mkdir -p /etc/containerd
			sudo sh -c "containerd config default > /etc/containerd/config.toml"
			sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
	else
			SysDGroup=$(cat /etc/containerd/config.toml | grep SystemdCgroup | sed 's/ //g' | sed 's/=//g')
			if [ "$SysDGroup" == "SystemdCgroupfalse" ]; then
				 sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
			fi
	fi
 }

containerdCGroup_Driver

$SYSTMD disable $DISABLE_DAEMON; $SYSTMD stop $DISABLE_DAEMON
echo "Restarting containerd"
$SYSTMD daemon-reload
$SYSTMD restart $ENABLE_DAEMON; $SYSTMD enable $ENABLE_DAEMON
$APTGET-mark hold $KUBE_PKG
#
echo "Installing helm packager"
# sudo curl $HELM_INSTALLURL | bash
sudo snap install helm --classic
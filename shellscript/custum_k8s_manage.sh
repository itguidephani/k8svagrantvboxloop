#!/bin/bash

## https://www.downloadkubernetes.com/ ###

export VBOX_INTERNAL=192.168.56
export LOADBALANCER_ADDRESS=${VBOX_INTERNAL}.30

export KUBE_TOOLS_DUMP="/opt/kubernets-tools"
export KUBE_TOOLS_CERTS="$KUBE_TOOLS_DUMP/certs/"

export k8sVERSION=v1.31.3
export k8sURL=https://dl.k8s.io/${k8sVERSION}/bin/linux/amd64
export k8sBIN="apiextensions-apiserver kube-aggregator kube-apiserver kube-controller-manager kube-log-runner kube-proxy kube-scheduler kubeadm kubectl kubectl-convert kubelet mounter"
export DOWNk8s="$KUBE_TOOLS_DUMP/bin/$k8sVERSION"

export ETCD_VER=v3.5.17
export GOOGLE_URL='https://storage.googleapis.com/etcd'
export GITHUB_URL='https://github.com/etcd-io/etcd/releases/download'
export DOWNLOAD_URL="${GOOGLE_URL}"
export ETCDDDIR="$KUBE_TOOLS_DUMP/etcd"


export k8s_modules01=("overlay" "br_netfilter")
export KRMODULESK8S='/etc/modules-load.d/k8s_modules.conf'
export k8s_kernel_nw01=("net.ipv4.ip_forward=1" "net.bridge.bridge-nf-call-iptables=1" "net.bridge.bridge-nf-call-ip6tables=1")
export SYSCTLK8S99='/etc/sysctl.d/99-kubernetes.conf'

export SYSTMD='sudo systemctl'
export DISABLE_DAEMON='apparmor'
export ENABLE_DAEMON='containerd'

export APTGET='sudo apt-get'
export REQ_PPK='apt-transport-https ca-certificates curl gpg jq'

export KUBE_PKG='containerd'

sudo mkdir -p $KUBE_TOOLS_CERTS

SwapOF(){
    swap_status=$(swapon --noheadings);	if [ -z "$swap_status" ]; then  echo "Swap memory is OFF."; else sudo swapoff -a; sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab;(echo "@reboot /sbin/swapoff -a") | sudo crontab - || true; fi
 }

SwapOF

InstallREQPKG(){
	$APTGET clean all
	echo "Update packages list"
	$APTGET update
	echo "Install containerd"
	$APTGET -y install $REQ_PPK $KUBE_PKG
 }

KernelContainerD_Modules(){
  for LoMD in "${k8s_modules01[@]}"; do
		if lsmod | grep -q "^${LoMD} "; then
			echo "The module '${LoMD}' is already loaded."
		else
			if ! grep -q "^${LoMD}$" "$KRMODULESK8S"; then
				echo "${LoMD}" | sudo tee -a "$KRMODULESK8S" > /dev/null
				echo "Module '${LoMD}' added to $KRMODULESK8S."
			fi
			sudo modprobe "${LoMD}"
			if lsmod | grep -q "^${LoMD} "; then
				echo "The module '${LoMD}' has been loaded."
			else
				echo "Failed to load the module '${LoMD}'."
			fi
		fi
  done
 }

K8sNW_KERNL_Parameters(){
  if [ ! -f "$SYSCTLK8S99" ]; then
		for item1 in "${k8s_kernel_nw01[@]}"; do
			echo "$item1" | sudo tee -a "$SYSCTLK8S99" > /dev/null
			sudo sysctl -w "$item1"
		done
  fi

  for item1 in "${k8s_kernel_nw01[@]}"; do
		key=$(echo "$item1" | cut -d'=' -f1)
		value=$(echo "$item1" | cut -d'=' -f2)
		current_value=$(sysctl -n "$key" 2>/dev/null)

		if [ "$current_value" != "$value" ]; then
			sudo sysctl -w "$item1"
		fi

		if ! grep -Fxq "$item1" "$SYSCTLK8S99"; then
			echo "$item1" | sudo tee -a "$SYSCTLK8S99" > /dev/null
			sudo sysctl -w "$item1"
		fi
  done
  sudo sysctl --system &>/dev/null
 }

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

wget-bin-k8s(){
   # Create target directory once
	sudo mkdir -p $DOWNk8s
    
	# Loop through each binary and download it
	for k8sbins in $k8sBIN; do
		# Download binary
		sudo wget -P $DOWNk8s ${k8sURL}/$k8sbins
		sudo chown -R root:root $DOWNk8s
		sudo chmod +x $DOWNk8s/*
		# Remove old symlink if it exists
		sudo rm -f /usr/local/bin/$k8sbins
		# Create a new symlink
		sudo ln -s $DOWNk8s/$k8sbins /usr/local/bin/$k8sbins
	done
 }
	
Install_etcd_cli(){
   sudo mkdir -p $ETCDDDIR
   sudo curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o $ETCDDDIR/etcd-${ETCD_VER}-linux-amd64.tar.gz
   sudo tar xzvf $ETCDDDIR/etcd-${ETCD_VER}-linux-amd64.tar.gz -C $ETCDDDIR/
   sudo rm -f /usr/local/bin/etcd /usr/local/bin/etcdutl /usr/local/bin/etcdctl
   sudo ln -s $ETCDDDIR/etcd-$ETCD_VER-linux-amd64/etcd /usr/local/bin/etcd
   sudo ln -s $ETCDDDIR/etcd-$ETCD_VER-linux-amd64/etcdctl /usr/local/bin/etcdctl
   sudo ln -s $ETCDDDIR/etcd-$ETCD_VER-linux-amd64/etcdutl /usr/local/bin/etcdutl
 }

Install_helm_cli(){
	echo "Installing helm packager"
	# sudo curl $HELM_INSTALLURL | bash
	sudo snap install helm --classic
 }

create_openssl_cnf_kube(){
cat > $KUBE_TOOLS_CERTS/openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 10.96.0.1
IP.2 = ${VBOX_INTERNAL}.11
IP.3 = ${VBOX_INTERNAL}.12
IP.4 = ${VBOX_INTERNAL}.30
IP.5 = 127.0.0.1
EOF
 }

create_openssl_cnf_etcd(){
cat > $KUBE_TOOLS_CERTS/openssl-etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${VBOX_INTERNAL}.11
IP.2 = ${VBOX_INTERNAL}.12
IP.3 = 127.0.0.1
EOF
 }

creating_openssl_certs_kube8s(){
	# Certificate Authority
	openssl genrsa -out $KUBE_TOOLS_CERTS/k8s_ca.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/k8s_ca.key -subj "/CN=KUBERNETES-CA" -out $KUBE_TOOLS_CERTS/k8s_ca.csr
	openssl x509 -req -in $KUBE_TOOLS_CERTS/k8s_ca.csr -signkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial  -out $KUBE_TOOLS_CERTS/k8s_ca.crt -days 1000

	# Admin Certificate
	openssl genrsa -out $KUBE_TOOLS_CERTS/k8s_admin.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/k8s_admin.key -subj "/CN=admin/O=system:masters" -out $KUBE_TOOLS_CERTS/k8s_admin.csr
	openssl x509 -req -in $KUBE_TOOLS_CERTS/k8s_admin.csr -CA $KUBE_TOOLS_CERTS/k8s_ca.crt -CAkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial  -out $KUBE_TOOLS_CERTS/k8s_admin.crt -days 1000

	# The Controller Manager Client Certificate
	openssl genrsa -out $KUBE_TOOLS_CERTS/kube-controller-manager.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/kube-controller-manager.key -subj "/CN=system:kube-controller-manager/O=system:kube-controller-manager" -out $KUBE_TOOLS_CERTS/kube-controller-manager.csr
	openssl x509 -req -in $KUBE_TOOLS_CERTS/kube-controller-manager.csr -CA $KUBE_TOOLS_CERTS/k8s_ca.crt -CAkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial -out $KUBE_TOOLS_CERTS/kube-controller-manager.crt -days 1000

	# The Kube Proxy Client Certificate
	openssl genrsa -out $KUBE_TOOLS_CERTS/kube-proxy.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/kube-proxy.key -subj "/CN=system:kube-proxy/O=system:kube-proxy" -out $KUBE_TOOLS_CERTS/kube-proxy.csr
	openssl x509 -req -in $KUBE_TOOLS_CERTS/kube-proxy.csr -CA $KUBE_TOOLS_CERTS/k8s_ca.crt -CAkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial  -out $KUBE_TOOLS_CERTS/kube-proxy.crt -days 1000

	# The Scheduler Client Certificate
	openssl genrsa -out $KUBE_TOOLS_CERTS/kube-scheduler.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/kube-scheduler.key -subj "/CN=system:kube-scheduler/O=system:kube-scheduler" -out $KUBE_TOOLS_CERTS/kube-scheduler.csr
	openssl x509 -req -in $KUBE_TOOLS_CERTS/kube-scheduler.csr -CA $KUBE_TOOLS_CERTS/k8s_ca.crt -CAkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial  -out $KUBE_TOOLS_CERTS/kube-scheduler.crt -days 1000

	# The Kubernetes API Server Certificate
	openssl genrsa -out $KUBE_TOOLS_CERTS/kube-apiserver.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/kube-apiserver.key -subj "/CN=kube-apiserver" -out $KUBE_TOOLS_CERTS/kube-apiserver.csr -config $KUBE_TOOLS_CERTS/openssl.cnf
	openssl x509 -req -in $KUBE_TOOLS_CERTS/kube-apiserver.csr -CA $KUBE_TOOLS_CERTS/k8s_ca.crt -CAkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial -out $KUBE_TOOLS_CERTS/kube-apiserver.crt -extensions v3_req -extfile $KUBE_TOOLS_CERTS/openssl.cnf -days 1000

	# The ETCD Server Certificate
	openssl genrsa -out $KUBE_TOOLS_CERTS/etcd-server.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/etcd-server.key -subj "/CN=etcd-server" -out $KUBE_TOOLS_CERTS/etcd-server.csr -config $KUBE_TOOLS_CERTS/openssl-etcd.cnf
	openssl x509 -req -in $KUBE_TOOLS_CERTS/etcd-server.csr -CA $KUBE_TOOLS_CERTS/k8s_ca.crt -CAkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial  -out $KUBE_TOOLS_CERTS/etcd-server.crt -extensions v3_req -extfile $KUBE_TOOLS_CERTS/openssl-etcd.cnf -days 1000

	# The Service Account Certificate
	openssl genrsa -out $KUBE_TOOLS_CERTS/service-account.key 2048
	openssl req -new -key $KUBE_TOOLS_CERTS/service-account.key -subj "/CN=service-accounts" -out $KUBE_TOOLS_CERTS/service-account.csr
	openssl x509 -req -in $KUBE_TOOLS_CERTS/service-account.csr -CA $KUBE_TOOLS_CERTS/k8s_ca.crt -CAkey $KUBE_TOOLS_CERTS/k8s_ca.key -CAcreateserial  -out $KUBE_TOOLS_CERTS/service-account.crt -days 1000
 }

FinalJOBS(){
	InstallREQPKG
	KernelContainerD_Modules
	K8sNW_KERNL_Parameters
	containerdCGroup_Driver
	wget-bin-k8s
	Install_etcd_cli
	Install_helm_cli
 }

Check_role_n_assign(){
	if [ "$ROLE" == "master" ]; then
		FinalJOBS
	elif [ "$ROLE" == "worker" ]; then
		echo "worker node"
	else
		echo "Invalid argument. Please specify 'master' or 'worker'."
    exit 1
	fi
  }

create_openssl_cnf_kube
create_openssl_cnf_etcd
creating_openssl_certs_kube8s
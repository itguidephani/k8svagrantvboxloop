#!/bin/bash

# Set default versions
K8S_VERSION="${K8S_VERSION:-1.27.4}"
CONTAINERD_VERSION="${CONTAINERD_VERSION:-1.6.24}"
METALLB_VERSION="${METALLB_VERSION:-v0.13.7}"
LONGHORN_VERSION="${LONGHORN_VERSION:-v1.4.1}"
NGINX_VERSION="${NGINX_VERSION:-latest}"

# Check root permissions
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

export k8s_modules01=("overlay" "br_netfilter")
export KRMODULESK8S='/etc/modules-load.d/k8s_modules.conf'
export k8s_kernel_nw01=("net.ipv4.ip_forward=1" "net.bridge.bridge-nf-call-iptables=1" "net.bridge.bridge-nf-call-ip6tables=1")
export SYSCTLK8S99='/etc/sysctl.d/99-kubernetes.conf'

export KUBECTLVER='v1.31'
export INSTALLURL_DEB="https://pkgs.k8s.io/core:/stable:/${KUBECTLVER}/deb"
export APTKY_DEB_K8='/etc/apt/keyrings/kubernetes-apt-keyring.gpg'
export DEBREPO="/etc/apt/sources.list.d/kubernetes.list"

export SYSTMD='sudo systemctl'
export DISABLE_DAEMON='apparmor'
export ENABLE_DAEMON='containerd kubelet'

export APTGET='sudo apt-get'
export REQ_PPK='apt-transport-https ca-certificates curl gpg jq'

export KUBE_PKG='containerd jq kubelet kubeadm kubectl'

export ETCD_VER=v3.5.17
export GOOGLE_URL='https://storage.googleapis.com/etcd'
export GITHUB_URL='https://github.com/etcd-io/etcd/releases/download'
export DOWNLOAD_URL="${GOOGLE_URL}"
export ETCDDDIR='/opt/kubernets-tools/etcd'

### END K8S Cluster ####

SwapOF(){
    swap_status=$(swapon --noheadings);	if [ -z "$swap_status" ]; then  echo "Swap memory is OFF."; else sudo swapoff -a; sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab;(echo "@reboot /sbin/swapoff -a") | sudo crontab - || true; fi
 }
SwapOF

InstallREQPKG(){
	curl -fsSL $INSTALLURL_DEB/Release.key | sudo gpg --dearmor -o $APTKY_DEB_K8
	echo "deb [signed-by=${APTKY_DEB_K8}] ${INSTALLURL_DEB}/ /" | sudo tee $DEBREPO
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

Install_etcd_cli(){
   sudo mkdir -p $ETCDDDIR
   sudo curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o $ETCDDDIR/etcd-${ETCD_VER}-linux-amd64.tar.gz
   sudo tar xzvf $ETCDDDIR/etcd-${ETCD_VER}-linux-amd64.tar.gz -C $ETCDDDIR/
   sudo rm -f /usr/local/bin/etcd /usr/local/bin/etcdctl /usr/local/bin/etcdutl
   sudo ln -s $ETCDDDIR/etcd-$ETCD_VER-linux-amd64/etcdctl /usr/local/bin/etcd
   sudo ln -s $ETCDDDIR/etcd-$ETCD_VER-linux-amd64/etcdctl /usr/local/bin/etcdctl
   sudo ln -s $ETCDDDIR/etcd-$ETCD_VER-linux-amd64/etcdctl /usr/local/bin/etcdutl
 }

InstallREQPKG
KernelContainerD_Modules
K8sNW_KERNL_Parameters
containerdCGroup_Driver

$SYSTMD disable $DISABLE_DAEMON; $SYSTMD stop $DISABLE_DAEMON
echo "Restarting containerd"
$SYSTMD daemon-reload
$SYSTMD restart $ENABLE_DAEMON; $SYSTMD enable $ENABLE_DAEMON
sudo apt-mark hold $KUBE_PKG

Install_helm_cli(){
	echo "Installing helm packager"
	# sudo curl $HELM_INSTALLURL | bash
	sudo snap install helm --classic
 }

Check_role_n_assign(){
	if [ "$ROLE" == "master" ]; then
		Install_etcd_cli
		Install_helm_cli
	elif [ "$ROLE" == "worker" ]; then
		echo "worker node"
	else
		echo "Invalid argument. Please specify 'master' or 'worker'."
    exit 1
	fi
  }
# Update system and install dependencies
echo "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y curl wget apt-transport-https kubeadm kubectl kubelet containerd

# Initialize Kubernetes cluster
echo "Initializing Kubernetes cluster..."
kubeadm init --kubernetes-version="$K8S_VERSION" --pod-network-cidr=192.168.0.0/16

# Configure kubeconfig
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Install MetalLB
echo "Deploying MetalLB version $METALLB_VERSION..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/$METALLB_VERSION/manifests/metallb.yaml

# Configure MetalLB with address pool
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.240-192.168.1.250
EOF

# Install Longhorn
echo "Deploying Longhorn version $LONGHORN_VERSION..."
kubectl create namespace longhorn-system
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/$LONGHORN_VERSION/deploy/longhorn.yaml

# Deploy Custom NGINX Application using MetalLB
echo "Deploying custom NGINX application with MetalLB..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-nginx
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: custom-nginx
  template:
    metadata:
      labels:
        app: custom-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:$NGINX_VERSION
        volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
        ports:
        - containerPort: 80
      volumes:
      - name: web-content
        configMap:
          name: custom-web-pages
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-web-pages
  namespace: default
data:
  index.html: |
    <html>
    <head><title>Welcome to Custom Nginx!</title></head>
    <body>
      <h1>Welcome to Custom Nginx Page!</h1>
      <p>This is a custom deployment in Kubernetes using MetalLB.</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: custom-nginx-service
  namespace: default
spec:
  selector:
    app: custom-nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer
EOF

echo "Kubernetes Cluster Setup Completed Successfully!"

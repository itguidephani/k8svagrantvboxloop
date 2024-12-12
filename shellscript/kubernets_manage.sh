#!/bin/bash
###  K8S Cluster ####
set -e

export VBOX_INTERNAL=192.168.56

ROLE=$1
## Check if an argument is provided
if [ "$#" -ne 1 ]; then
     echo "Usage: $0 <master|worker>"
     exit 1
fi
export USERMR='vagrant'
export KUBE_TOOLS="/opt/kubernets-tools"
export KUBE_TOOLS_YAML="${KUBE_TOOLS}/yaml"
export KUBE_TOOLS_YAML_NW="${KUBE_TOOLS_YAML}/network"
export KUBE_TOOLS_YAML_METALLB="${KUBE_TOOLS_YAML}/metallb"
export KUBE_TOOLS_YAML_DASHBOARD="${KUBE_TOOLS_YAML}/dashboard"
export k8s_modules01=("overlay" "br_netfilter")
export KRMODULESK8S='/etc/modules-load.d/k8s_modules.conf'
export k8s_kernel_nw01=("net.ipv4.ip_forward=1" "net.bridge.bridge-nf-call-iptables=1" "net.bridge.bridge-nf-call-ip6tables=1")
export SYSCTLK8S99='/etc/sysctl.d/99-kubernetes.conf'

export KUBECTLVER='v1.31'
export KUBEDASHBOARDVER='v2.0.0'
export KUBEDASHBOARDVER_PORT='8001'
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
export ETCDDDIR="${KUBE_TOOLS}/etcd"

export METALB_VERS='v0.11.0'
export WAVE_DEAMONSET='v2.8.1'
export LOADLBMETA_IPSRC='192.168.56.40-192.168.56.80'

### END K8S Cluster ####

SwapOF(){
    swap_status=$(swapon --noheadings);	if [ -z "$swap_status" ]; then  echo "Swap memory is OFF."; else sudo swapoff -a; sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab;(echo "@reboot /sbin/swapoff -a") | sudo crontab - || true; fi
 }

SwapOF

create_r_q_dir(){
	sudo mkdir -p $KUBE_TOOLS $KUBE_TOOLS_YAML $KUBE_TOOLS_YAML_METALLB $KUBE_TOOLS_YAML_NW $KUBE_TOOLS_YAML_DASHBOARD
	sudo chmod -R 777 $KUBE_TOOLS $KUBE_TOOLS_YAML $KUBE_TOOLS_YAML_NW $KUBE_TOOLS_YAML_METALLB $KUBE_TOOLS_YAML_DASHBOARD
 }

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

serv_crl_demon(){
	$SYSTMD disable $DISABLE_DAEMON; $SYSTMD stop $DISABLE_DAEMON
	echo "Restarting containerd"
	$SYSTMD daemon-reload
	$SYSTMD restart $ENABLE_DAEMON; $SYSTMD enable $ENABLE_DAEMON
	sudo apt-mark hold $KUBE_PKG
 }

usefull_tools_k8s(){
   wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -O $KUBE_TOOLS_YAML/components.yaml
 }

Install_wave_nw(){
	wget https://github.com/weaveworks/weave/releases/download/${WAVE_DEAMONSET}/weave-daemonset-k8s.yaml  -O $KUBE_TOOLS_YAML_NW/weave-daemonset-k8s.yaml
	wget https://docs.projectcalico.org/manifests/calico.yaml -O $KUBE_TOOLS_YAML_NW/calico.yaml
 }

Install_metalb_srv(){
cat <<EOFFF > $KUBE_TOOLS_YAML_METALLB/metal-lb-cm.yml
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
      - $LOADLBMETA_IPSRC
EOFFF

	wget https://raw.githubusercontent.com/metallb/metallb/${METALB_VERS}/manifests/namespace.yaml -O $KUBE_TOOLS_YAML_METALLB/metallb-namespace.yaml
	wget https://raw.githubusercontent.com/metallb/metallb/${METALB_VERS}/manifests/metallb.yaml -O $KUBE_TOOLS_YAML_METALLB/metallb.yaml
 }

run_kube_proxy_dashboads(){

   wget https://raw.githubusercontent.com/kubernetes/dashboard/${KUBEDASHBOARDVER}/aio/deploy/recommended.yaml -O $KUBE_TOOLS_YAML_DASHBOARD/dashboard_${KUBEDASHBOARDVER}_aio_recommended.yaml


cat <<EOFGG > $KUBE_TOOLS_YAML_DASHBOARD/dashboard-admin.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
----
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOFGG


cat <<EOFHH > $KUBE_TOOLS_YAML_DASHBOARD/dashboard-read-only.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: read-only-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
  name: read-only-clusterrole
  namespace: default
rules:
- apiGroups:
  - ""
  resources: ["*"]
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - extensions
  resources: ["*"]
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources: ["*"]
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-only-binding
roleRef:
  kind: ClusterRole
  name: read-only-clusterrole
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: read-only-user
  namespace: kubernetes-dashboard
EOFHH

cat <<EOFII > $KUBE_TOOLS_YAML_DASHBOARD/kubectlproxy.service
[Unit]
Description=kubectl proxy ${KUBEDASHBOARDVER_PORT}
After=network.target kubelet.service

[Service]
User=root
ExecStart=/bin/bash -c "export KUBECONFIG=/etc/kubernetes/admin.conf; /usr/bin/kubectl proxy --address=${VBOX_INTERNAL}.10 --port=${KUBEDASHBOARDVER_PORT} --accept-hosts "^*$""
StartLimitInterval=0
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOFII

cat <<EOFJJ > $KUBE_TOOLS_YAML_DASHBOARD/README.md

https://upcloud.com/resources/tutorials/deploy-kubernetes-dashboard

The first thing to know about the web UI is that it can only be accessed using the localhost address on the machine it runs on. This means we need to have an SSH tunnel to the server. For most OS, you can create an SSH tunnel using this command. Replace the <user> and <master_public_IP> with the relevant details to your Kubernetes cluster.

ssh -L localhost:8001:127.0.0.1:8001 <user>@<master_public_IP>
After you’ve logged in, you can deploy the dashboard itself with the following single command.

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
If your cluster is working correctly, you should see an output confirming the creation of a bunch of Kubernetes components, as in the example below.

kubectl get pods -A
You can then continue ahead with creating the required user accounts.

mkdir ~/dashboard && cd ~/dashboard

Then, deploy the admin user role using the next command.

kubectl apply -f dashboard-admin.yaml

Get the admin token using the command below.

kubectl get secret -n kubernetes-dashboard $(kubectl get serviceaccount admin-user -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode

The token is created each time the dashboard is deployed and is required to log into the dashboard. Note that the token will change if the dashboard is stopped and redeployed.

3. Creating Read-Only user
You can create a read-only view for the cluster if you wish to provide access to your Kubernetes dashboard, for example, for demonstrative purposes.

kubectl apply -f dashboard-read-only.yaml

To allow users to log in via the read-only account, you’ll need to provide a token which can be fetched using the next command.

kubectl get secret -n kubernetes-dashboard $(kubectl get serviceaccount read-only-user -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode

4. Accessing the dashboard
We’ve deployed the dashboard and created user accounts for it. Next, we can start managing the Kubernetes cluster itself.

However, before we can log in to the dashboard, it needs to be made available by creating a proxy service on the localhost. Run the next command on your Kubernetes cluster.

kubectl proxy
Now, assuming that we have already established an SSH tunnel binding to the localhost port 8001 at both ends, open a browser to the link below.

http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

5. Stopping the dashboard
User roles that are no longer needed can be removed using the delete method.

kubectl delete -f dashboard-admin.yaml
kubectl delete -f dashboard-read-only.yaml

Likewise, if you want to disable the dashboard, it can be deleted just like any other deployment.

kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
EOFJJ

   sudo cp $KUBE_TOOLS_YAML_DASHBOARD/kubectlproxy.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable kubectlproxy.service
   sudo systemctl restart kubectlproxy.service
 }
comment_lines_readme(){
	kubectl taint nodes --all  node-role.kubernetes.io/control-plane:NoSchedule-
	kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule-
    kubectl taint nodes --all node-role.kubernetes.io/master-
}

Install_helm_cli(){
	echo "Installing helm packager"
	# sudo curl $HELM_INSTALLURL | bash
	sudo snap install helm --classic
 }

helm_repo_cmd_run(){
	K8S_HEML_COMMANDS=(
		helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
		helm repo add jetstack https://charts.jetstack.io
		# Add kubernetes-dashboard repository
		helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
		# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
		helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
		helm repo update
		kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
		comment_lines_readme
		kubectl apply -f $KUBE_TOOLS_YAML/components.yaml
		kubectl apply -f $KUBE_TOOLS_YAML_NW/calico.yaml
	)
	for CMDR01 in "${K8S_HEML_COMMANDS[@]}"; do
		echo "Executing: $CMDR01"
		su - "$USERMR" -c "$CMDR01"
	done
 }

DCreate_Cluster(){
  sudo kubeadm config images pull
  sudo kubeadm init --apiserver-advertise-address ${VBOX_INTERNAL}.10 --control-plane-endpoint ${VBOX_INTERNAL}.10 --node-name $(hostname -s)
  mkdir -p /home/$USERMR/.kube
  cp -i /etc/kubernetes/admin.conf /home/$USERMR/.kube/config
  chown $USERMR:$USERMR /home/$USERMR/.kube/config
  Install_helm_cli
 }

Check_role_n_assign(){
	if [ "$ROLE" == "master" ]; then
			create_r_q_dir
			InstallREQPKG
			KernelContainerD_Modules
			K8sNW_KERNL_Parameters
			containerdCGroup_Driver
			Install_etcd_cli
			serv_crl_demon
			usefull_tools_k8s
			Install_wave_nw
			Install_metalb_srv
			run_kube_proxy_dashboads
			DCreate_Cluster
			helm_repo_cmd_run
	elif [ "$ROLE" == "worker" ]; then
		echo "worker node"
		InstallREQPKG
		KernelContainerD_Modules
		K8sNW_KERNL_Parameters
		containerdCGroup_Driver
	else
		echo "Invalid argument. Please specify 'master' or 'worker'."
    exit 1
	fi
  }

Check_role_n_assign
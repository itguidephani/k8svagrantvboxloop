#!/bin/bash
###  K8S Cluster ####
set +e

ROLE=$1
## Check if an argument is provided
if [ "$#" -ne 1 ]; then
     echo "Usage: $0 <master|worker>"
     exit 1
fi

# IP Range
export VBOX_INTERNAL=192.168.56
export LOADLBMETA_IPSRC="192.168.56.40-192.168.56.60"
# User
export USERMR='vagrant'
# Versions
export KUBECTLVER='v1.31'
export KUBEDASHBOARDVER='v2.0.0'
export ETCD_VER=v3.5.17
export METALB_VERS='main'
export WAVE_DEAMONSET='v2.8.1'
export CERTSMGR='v1.16.2'
# Required Dir
export KUBE_TOOLS="/opt/kubernets-tools"
export KUBE_TOOLS_YAML="${KUBE_TOOLS}/yaml"
export KUBE_TOOLS_YAML_NW="${KUBE_TOOLS_YAML}/network"
export KUBE_TOOLS_YAML_METALLB="${KUBE_TOOLS_YAML}/metallb"
export KUBE_TOOLS_YAML_DASHBOARD="${KUBE_TOOLS_YAML}/dashboard"
export KUBE_TOOLS_YAML_RANCHER="${KUBE_TOOLS_YAML}/rancher"
export KUBE_TOOLS_YAML_CRTMGR="${KUBE_TOOLS_YAML}/certs-manager"
export ETCDDDIR="${KUBE_TOOLS}/etcd"
## Config Files and modules
export k8s_modules01=("overlay" "br_netfilter")
export KRMODULESK8S='/etc/modules-load.d/k8s_modules.conf'
export k8s_kernel_nw01=("net.ipv4.ip_forward=1" "net.bridge.bridge-nf-call-iptables=1" "net.bridge.bridge-nf-call-ip6tables=1")
export SYSCTLK8S99='/etc/sysctl.d/99-kubernetes.conf'
export SYSTMD='sudo systemctl'
export DISABLE_DAEMON='apparmor'
export ENABLE_DAEMON='containerd kubelet'
# Package
export APTGET='sudo apt-get'
export REQ_PPK='apt-transport-https ca-certificates curl gpg jq'
export KUBE_PKG='containerd kubelet kubeadm kubectl helm'
# Port Numbers 
export KUBEDASHBOARDVER_PORT='8001'
export RANCHERHTP='7080'
export RANCHERHTPS='7443'
# URL
export INSTALLURL_DEB="https://pkgs.k8s.io/core:/stable:/${KUBECTLVER}/deb"
export HELM_INSTALLURL_DEB='https://baltocdn.com/helm/stable/debian/ all main'
export APTKY_DEB_K8='/etc/apt/keyrings/kubernetes-apt-keyring.gpg'
export APTKY_DEB_HELM='/etc/apt/keyrings/helm.gpg'
export DEBREPO="/etc/apt/sources.list.d/kubernetes.list"
export HELM_DEBREPO="/etc/apt/sources.list.d/helm-stable-debian.list"
export GOOGLE_URL='https://storage.googleapis.com/etcd'
export GITHUB_URL='https://github.com/etcd-io/etcd/releases/download'
export DOWNLOAD_URL="${GOOGLE_URL}"
### END K8S Cluster ####

SwapOF(){
    swap_status=$(swapon --noheadings);	if [ -z "$swap_status" ]; then  echo "Swap memory is OFF."; else sudo swapoff -a; sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab;(echo "@reboot /sbin/swapoff -a") | sudo crontab - || true; fi
 }

SwapOF

create_r_q_dir(){
	sudo mkdir -p $KUBE_TOOLS $KUBE_TOOLS_YAML $KUBE_TOOLS_YAML_METALLB $KUBE_TOOLS_YAML_NW $KUBE_TOOLS_YAML_DASHBOARD $KUBE_TOOLS_YAML_RANCHER $KUBE_TOOLS_YAML_CRTMGR
	sudo chmod -R 777 $KUBE_TOOLS
 }

InstallREQPKG(){
	curl -fsSL $INSTALLURL_DEB/Release.key | sudo gpg --dearmor -o $APTKY_DEB_K8
	curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee $APTKY_DEB_HELM > /dev/null
	echo "deb [signed-by=${APTKY_DEB_K8}] ${INSTALLURL_DEB}/ /" | sudo tee $DEBREPO
	echo "deb [arch=$(dpkg --print-architecture) signed-by=$APTKY_DEB_HELM] ${HELM_INSTALLURL_DEB}" | sudo tee $HELM_DEBREPO
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


docker_shell_script(){
sudo groupadd docker || sudo usermod -aG docker $USERMR
newgrp docker << EOFLL
id
EOFLL

sudo tee -a /usr/local/bin/rancher_run_docker <<EOFPP
sudo apt-get install docker.io -y
sudo groupadd docker || sudo usermod -aG docker $USER
newgrp docker << EOFLLL
id
sudo systemctl enable docker; sudo systemctl restart docker
DRST=\$(docker ps  | grep rancher | grep Up | wc -l);if [ "\$DRST" -gt 0 ]; then docker ps | grep rancher; else docker run -d --restart=unless-stopped -p \${RANCHERHTP}:\${RANCHERHTP} -p \${RANCHERHTPS}:\${RANCHERHTPS} --privileged rancher/rancher && DOCKER_RANCHER_ID=\$(docker ps | grep rancher | awk '{print \$1}');fi
exit
EOFLLL
DOCKER_RANCHER_ID=\$(docker ps | grep rancher | awk '{print \$1}')
sudo docker logs \$DOCKER_RANCHER_ID 2>&1 | grep "Bootstrap Password"  | awk -F: '{print "Rancher firstboot Password :" \$4}' | sudo tee $KUBE_TOOLS_YAML_RANCHER/RANCHER_FIRSTBOOT_PASSWD
EOFPP

sudo chmod +x /usr/local/bin/rancher_run_docker
 }

docker_cfg_man_rancher(){
	/usr/local/bin/rancher_run_docker
 }
 
Install_metalb_srv(){
cat <<EOFFF > $KUBE_TOOLS_YAML_METALLB/metallb-configmap.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
      - $LOADLBMETA_IPSRC
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOFFF

	wget https://raw.githubusercontent.com/metallb/metallb/${METALB_VERS}/config/manifests/metallb-native.yaml -O $KUBE_TOOLS_YAML_METALLB/metallb-native.yaml
 }

run_kube_proxy_dashboads(){

   wget https://raw.githubusercontent.com/kubernetes/dashboard/${KUBEDASHBOARDVER}/aio/deploy/recommended.yaml -O $KUBE_TOOLS_YAML_DASHBOARD/dashboard_${KUBEDASHBOARDVER}_aio_recommended.yaml

cat <<EOFGG > $KUBE_TOOLS_YAML_DASHBOARD/dashboard-srv-admin.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
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

 }
comment_lines_readme(){
	sudo su - "$USERMR" -c  "kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
	sudo su - "$USERMR" -c  "kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule-"
    sudo su - "$USERMR" -c  "kubectl taint nodes --all node-role.kubernetes.io/master-"
}

Install_helm_cli(){
	echo "Installing helm packager"
	# sudo curl $HELM_INSTALLURL | bash
	sudo snap install helm --classic
 }

helm_repo_cmd_run(){
	Install_helm_cli
	sudo su - "$USERMR" -c  "helm repo add rancher-stable https://releases.rancher.com/server-charts/stable"
	sudo su - "$USERMR" -c  "helm repo add jetstack https://charts.jetstack.io"
	sudo su - "$USERMR" -c  "helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/"
	sudo su - "$USERMR" -c  "helm repo update"
 }

get_cert-manager(){
   wget https://github.com/cert-manager/cert-manager/releases/download/${CERTSMGR}/cert-manager.crds.yaml -O $KUBE_TOOLS_YAML_CRTMGR/cert-manager.crds.yaml
 }

kube_proxy_systd(){
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

   sudo cp $KUBE_TOOLS_YAML_DASHBOARD/kubectlproxy.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable kubectlproxy.service
   sudo systemctl restart kubectlproxy.service
 }

DCreate_Cluster(){
  sudo kubeadm config images pull
  sudo kubeadm init --apiserver-advertise-address ${VBOX_INTERNAL}.10 --control-plane-endpoint ${VBOX_INTERNAL}.10 --node-name $(hostname -s)
  mkdir -p /home/$USERMR/.kube
  cp -i /etc/kubernetes/admin.conf /home/$USERMR/.kube/config
  chown $USERMR:$USERMR /home/$USERMR/.kube/config
  sudo su - "$USERMR" -c  "kubectl apply -f ${KUBE_TOOLS_YAML_NW}/calico.yaml"
  sudo su - "$USERMR" -c  "kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
  sudo su - "$USERMR" -c  "kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule-"
  sudo su - "$USERMR" -c  "kubectl apply -f ${KUBE_TOOLS_YAML}/components.yaml"
  sudo su - "$USERMR" -c  "kubectl apply -f ${KUBE_TOOLS_YAML_METALLB}/metallb-native.yaml"
  sudo su - "$USERMR" -c  "helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard"
  sudo su - "$USERMR" -c  "nohup kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443 &>/tmp/portfdasd.log"
  sudo su - "$USERMR" -c  "until kubectl get apiservices v1beta1.metrics.k8s.io | grep -i false;do kubectl delete pod -n kube-system -l k8s-app=metrics-server || kubectl apply -f ${KUBE_TOOLS_YAML}/components.yaml;done"
  sudo su - "$USERMR" -c  "kubectl create namespace cattle-system"
  sudo su - "$USERMR" -c  "kubectl apply -f ${KUBE_TOOLS_YAML_CRTMGR}/cert-manager.crds.yaml"
  sudo su - "$USERMR" -c  "helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true"
  sudo su - "$USERMR" -c  "kubectl get pods --namespace cert-manager"
  sudo su - "$USERMR" -c  "kubectl apply -f ${KUBE_TOOLS_YAML_METALLB}/metallb-configmap.yaml"
 }

Check_role_n_assign(){
	if [ "$ROLE" == "master" ]; then
			create_r_q_dir
			InstallREQPKG
			KernelContainerD_Modules
			K8sNW_KERNL_Parameters
			containerdCGroup_Driver
#			Install_etcd_cli
			serv_crl_demon
			usefull_tools_k8s
			Install_wave_nw
			Install_metalb_srv
			docker_shell_script
#			docker_cfg_man_rancher
			#run_kube_proxy_dashboads
			helm_repo_cmd_run
			DCreate_Cluster
#			kube_proxy_systd
	elif [ "$ROLE" == "worker" ]; then
		echo "worker node"
		InstallREQPKG
		KernelContainerD_Modules
		K8sNW_KERNL_Parameters
		containerdCGroup_Driver
		serv_crl_demon
		Install_helm_cli
	else
		echo "Invalid argument. Please specify 'master' or 'worker'."
    exit 1
	fi
  }

Check_role_n_assign
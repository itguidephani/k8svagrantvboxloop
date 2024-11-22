NUM_WORKER_NODES = 3
K8S_IP_NW = "192.168.10."
M_IP_START = 10
W_IP_START = 20

Vagrant.configure("2") do |config|
  # Master Node Configuration
  config.vm.define "k8scpmt" do |k8scpm01|
    k8scpm01.vm.box = "ubuntu/jammy64"
    k8scpm01.vm.hostname = 'k8scpmaster01'
    k8scpm01.vm.network "private_network", ip: "#{K8S_IP_NW}#{M_IP_START}"

    # VirtualBox Configuration for Master Node (2GB RAM)
    k8scpm01.vm.provider "virtualbox" do |v|
      v.memory = 4096  # 2GB for the master node
      v.cpus = 4
    end

    # Provision master node
    k8scpm01.vm.provision "shell", inline: <<-SHELL
      NODE_IP=$(ip -o -4 addr show | grep "#{K8S_IP_NW}" | awk '{print $4}' | awk -F/ '{print $1}')
      sudo sed -i -E "s|^KUBELET_EXTRA_ARGS=.*|KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}|" /etc/default/kubelet
      echo "#{K8S_IP_NW}#{M_IP_START} k8scpmaster01 master" | sudo tee -a /etc/hosts > /dev/null
    SHELL
  end

  # Worker Nodes Configuration
  (1..NUM_WORKER_NODES).each do |i|
    worker_hostname = "k8worker#{i}"
    worker_ip = "#{K8S_IP_NW}#{W_IP_START + i - 1}"

    config.vm.define worker_hostname do |worker|
      worker.vm.box = "ubuntu/jammy64"
      worker.vm.hostname = worker_hostname
      worker.vm.network "private_network", ip: worker_ip

      # VirtualBox Configuration for Worker Node (4GB RAM)
      worker.vm.provider "virtualbox" do |v|
        v.memory = 2048  # 4GB for the worker node
        v.cpus = 2
      end

      # Provision worker node
      worker.vm.provision "shell", inline: <<-SHELL
        NODE_IP=$(ip -o -4 addr show | grep "#{K8S_IP_NW}" | awk '{print $4}' | awk -F/ '{print $1}')
        sudo sed -i -E "s|^KUBELET_EXTRA_ARGS=.*|KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}|" /etc/default/kubelet
        echo "#{worker_ip} #{worker_hostname} worker" | sudo tee -a /etc/hosts > /dev/null
      SHELL
    end
  end

  # Shared Provisioning for All Nodes
  config.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  config.vm.provision "shell", inline: <<-SHELL
    # Add entries for master and workers in /etc/hosts
    echo "#{K8S_IP_NW}#{M_IP_START} k8scpmaster01 master" | sudo tee -a /etc/hosts > /dev/null
    for i in $(seq 1 #{NUM_WORKER_NODES}); do
      WORKER_IP=#{K8S_IP_NW}$(($W_IP_START + $i - 1))
      WORKER_HOSTNAME="k8worker${i}"
      echo "${WORKER_IP} ${WORKER_HOSTNAME} worker${i}" | sudo tee -a /etc/hosts > /dev/null
    done
    # Install utilities and run the Kubernetes management script
    sudo apt-get update
    sudo apt-get install -y dos2unix net-tools
    sudo dos2unix /tmp/kubernets_manage.sh
    bash -x /tmp/kubernets_manage.sh
  SHELL
end
Vagrant.configure("2") do |config|
	
    config.vm.define "k8scpmt" do |k8scpm01|
      k8scpm01.vm.box = "ubuntu/jammy64"
      k8scpm01.vm.hostname = 'k8scpmaster01'
      k8scpm01.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  
      # Configure networks
      k8scpm01.vm.network "private_network", ip: "192.168.10.10", auto_config: true
	  k8scpm01.vm.network "private_network",  ip: "172.16.0.10", auto_config: true,
        virtualbox__intnet: true
  
      # Provisioning: Install k8smaster node
      k8scpm01.vm.provision "shell", inline: <<-SHELL
	     if ! grep -q k8scpmaster01 /etc/hosts; then sudo echo  '192.168.10.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; then sudo echo  '172.16.0.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8worker01 /etc/hosts; then sudo echo  '192.168.10.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8worker01 /etc/hosts; then sudo echo  '172.16.0.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8worker02 /etc/hosts; then sudo echo  '192.168.10.21 k8worker02 worker02' >> /etc/hosts ;fi
		 if ! grep -q k8worker02 /etc/hosts; then sudo echo  '172.16.0.21 k8worker02 worker02' >> /etc/hosts ;fi
         sudo apt-get update
         sudo apt-get install dos2unix net-tools
         sudo dos2unix /tmp/kubernets_manage.sh 
         bash -x /tmp/kubernets_manage.sh
		 sudo sed -i -E -e "s|^KUBELET_EXTRA_ARGS=\$|KUBELET_EXTRA_ARGS=--node-ip=192.168.10.21|" /etc/default/kubelet
      SHELL
    end
    
    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
        v.customize ["modifyvm", :id, "--boot4", "disk", "--audio-enabled=off", "--nic-type1", "82543GC", "--nicpromisc1", "deny", "--nic-type2", "82545EM", "--nicpromisc2", "allow-all", "--nic-type3", "Am79C970A", "--nicpromisc3", "allow-vms"]
    end
  
    config.vm.define "k8wk1" do |k8wk01|
      k8wk01.vm.box = "ubuntu/jammy64"
      k8wk01.vm.hostname = 'k8worker01'
      k8wk01.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  
      # Configure networks
      k8wk01.vm.network "private_network", ip: "192.168.10.20", auto_config: true
	  k8wk01.vm.network "private_network",  ip: "172.16.0.20", auto_config: true,
        virtualbox__intnet: true
  
      # # Provisioning: Install k8worker node
      k8wk01.vm.provision "shell", inline: <<-SHELL
	     if ! grep -q k8scpmaster01 /etc/hosts; then sudo echo  '192.168.10.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; then sudo echo  '172.16.0.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8worker01 /etc/hosts; then sudo echo  '192.168.10.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8worker01 /etc/hosts; then sudo echo  '172.16.0.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8worker02 /etc/hosts; then sudo echo  '192.168.10.21 k8worker02 worker02' >> /etc/hosts ;fi
		 if ! grep -q k8worker02 /etc/hosts; then sudo echo  '172.16.0.21 k8worker02 worker02' >> /etc/hosts ;fi
         sudo apt-get update
         sudo apt-get install dos2unix net-tools
         sudo dos2unix /tmp/kubernets_manage.sh 
         bash -x /tmp/kubernets_manage.sh
		 sudo sed -i -E -e "s|^KUBELET_EXTRA_ARGS=\$|KUBELET_EXTRA_ARGS=--node-ip=192.168.10.21|" /etc/default/kubelet
      SHELL
    end
	
	config.vm.define "k8wk2" do |k8wk02|
      k8wk02.vm.box = "ubuntu/jammy64"
      k8wk02.vm.hostname = 'k8worker02'
      k8wk02.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  
      # Configure networks
      k8wk02.vm.network "private_network", ip: "192.168.10.21", auto_config: true
	  k8wk02.vm.network "private_network",  ip: "172.16.0.21", auto_config: true,
        virtualbox__intnet: true
  
      # # Provisioning: Install k8worker node
      k8wk02.vm.provision "shell", inline: <<-SHELL
	     if ! grep -q k8scpmaster01 /etc/hosts; then sudo echo  '192.168.10.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; then sudo echo  '172.16.0.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8worker01 /etc/hosts; then sudo echo  '192.168.10.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8worker01 /etc/hosts; then sudo echo  '172.16.0.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8worker02 /etc/hosts; then sudo echo  '192.168.10.21 k8worker02 worker02' >> /etc/hosts ;fi
		 if ! grep -q k8worker02 /etc/hosts; then sudo echo  '172.16.0.21 k8worker02 worker02' >> /etc/hosts ;fi
         sudo apt-get update
         sudo apt-get install dos2unix net-tools
         sudo dos2unix /tmp/kubernets_manage.sh 
         bash -x /tmp/kubernets_manage.sh
		 sudo sed -i -E -e "s|^KUBELET_EXTRA_ARGS=\$|KUBELET_EXTRA_ARGS=--node-ip=192.168.10.21|" /etc/default/kubelet
      SHELL
    end

end
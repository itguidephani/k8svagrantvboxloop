Vagrant.configure("2") do |config|
	
    config.vm.define "k8scpm" do |k8scpm01|
      k8scpm01.vm.box = "ubuntu/jammy64"
      k8scpm01.vm.hostname = 'k8scpmaster01'
      k8scpm01.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  
      # Configure networks
      k8scpm01.vm.network "private_network", ip: "192.168.56.10", auto_config: true
  
      # Provisioning: Install k8smaster node
      k8scpm01.vm.provision "shell", inline: <<-SHELL
	     if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.21 k8worker02 worker02' >> /etc/hosts ;fi
         sudo apt-get update
         sudo apt-get install dos2unix net-tools
         sudo dos2unix /tmp/kubernets_manage.sh 
         bash -x /tmp/kubernets_manage.sh master
		 sudo usermod -aG docker vagrant
      SHELL
    end
    
    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
        v.customize ["modifyvm", :id, "--audio-enabled=off"]
    end
  
    config.vm.define "k8wk1" do |k8wk01|
      k8wk01.vm.box = "ubuntu/jammy64"
      k8wk01.vm.hostname = 'k8worker01'
      k8wk01.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  
      # Configure networks
      k8wk01.vm.network "private_network", ip: "192.168.56.20", auto_config: true
  
      # # Provisioning: Install k8worker node
      k8wk01.vm.provision "shell", inline: <<-SHELL
	     if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.21 k8worker02 worker02' >> /etc/hosts ;fi
         sudo apt-get update
         sudo apt-get install dos2unix net-tools
         sudo dos2unix /tmp/kubernets_manage.sh 
         bash -x /tmp/kubernets_manage.sh worker
		 sudo usermod -aG docker vagrant
      SHELL
    end
	
	config.vm.define "k8wk2" do |k8wk02|
      k8wk02.vm.box = "ubuntu/jammy64"
      k8wk02.vm.hostname = 'k8worker02'
      k8wk02.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  
      # Configure networks
      k8wk02.vm.network "private_network", ip: "192.168.56.21", auto_config: true
  
      # # Provisioning: Install k8worker node
      k8wk02.vm.provision "shell", inline: <<-SHELL
	  	 if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.10 k8scpmaster01 master01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.20 k8worker01 worker01' >> /etc/hosts ;fi
		 if ! grep -q k8scpmaster01 /etc/hosts; sudo echo  '192.168.56.21 k8worker02 worker02' >> /etc/hosts ;fi
         sudo apt-get update
         sudo apt-get install dos2unix net-tools
         sudo dos2unix /tmp/kubernets_manage.sh 
         bash -x /tmp/kubernets_manage.sh worker
		 sudo usermod -aG docker vagrant
      SHELL
    end

end
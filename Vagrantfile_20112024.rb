Vagrant.configure("2") do |config|
    # Define the NGINX VM
	if Vagrant.has_plugin?("vagrant-hostmanager")
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.manage_guest = true
	
    config.vm.define "nginx_vm" do |nginx|
      nginx.vm.box = "ubuntu/jammy64"
      nginx.vm.hostname = 'masterk-01'
      nginx.vm.provision "file", source: "kubernets_manage.sh", destination: "/tmp/kubernets_manage.sh"
  
      # Configure networks
      # nginx.vm.network "private_network", type: "dhcp"  # Host-only network
      nginx.vm.network "private_network", ip: "192.168.56.10", auto_config: true
      nginx.vm.network "private_network",  type: "dhcp", 
        virtualbox__intnet: true
      nginx.vm.network "forwarded_port", guest: 80, host: 8080
  
      # Provisioning: Install NGINX
      nginx.vm.provision "shell", inline: <<-SHELL
         sudo apt-get update
         sudo apt-get install dos2unix
         sudo dos2unix /tmp/kubernets_manage.sh 
#        sudo apt-get install -y nginx
#        sudo systemctl start nginx
#        sudo systemctl enable nginx
         bash -x /tmp/kubernets_manage.sh master
      SHELL
    end
    
    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
#        v.customize ["modifyvm", :id, "--boot", "disk"]
        v.customize ["modifyvm", :id, "--audio-enabled=off"]
    end
  
    # Define the MySQL VM
    config.vm.define "mysql_vm" do |mysql|
      mysql.vm.box = "ubuntu/jammy64"
      mysql.vm.hostname = 'worker-01'
  
      # Configure networks
      # mysql.vm.network "private_network", type: "dhcp"  # Host-only network
      mysql.vm.network "private_network", ip: "192.168.56.20", auto_config: true
      mysql.vm.network "private_network",  type: "dhcp",
        virtualbox__intnet: true
      # Provisioning: Install MySQL
      mysql.vm.provision "shell", inline: <<-SHELL
#        sudo apt-get update
#        sudo apt-get install -y mysql-server
#        sudo systemctl start mysql
#        sudo systemctl enable mysql
         echo "Bye"
      SHELL
    end
  end
  
# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
    # The most common configuration options are documented and commented below.
    # For a complete reference, please see the online documentation at
    # https://docs.vagrantup.com.
    config.vm.network "forwarded_port", guest: 2375, host: 2375
    config.vm.network "forwarded_port", guest: 2379, host: 2379
    config.vm.network "forwarded_port", guest: 29091, host: 29091
    config.vm.network "forwarded_port", guest: 29092, host: 29092
    config.vm.network "public_network"

    # Every Vagrant development environment requires a box. You can search for
    # boxes at https://atlas.hashicorp.com/search.
    config.vm.box = "ubuntu/trusty64"

    config.vm.provider "virtualbox" do |vb|
        # Display the VirtualBox GUI when booting the machine
        vb.gui = false

        # Customize the amount of memory on the VM:
        vb.cpus = "2"
        vb.memory = "1024"

        # Setup additional block device for docker thinpool
        vb.customize ['createhd', '--filename', './thin.vdi', '--size', 10 * 1024]
        vb.customize ['storageattach', :id, '--storagectl', 'SATAController', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', './thin.vdi']
    end

    # ssh_config
    config.ssh.forward_agent = true
    config.ssh.forward_x11 = true
end

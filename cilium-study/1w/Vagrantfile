# Variables
K8SV = '1.33.2-1.1' # Kubernetes Version : apt list -a kubelet , ex) 1.32.5-1.1
CONTAINERDV = '1.7.27-1' # Containerd Version : apt list -a containerd.io , ex) 1.6.33-1
N = 2 # max number of worker nodes

# Base Image  https://portal.cloud.hashicorp.com/vagrant/discover/bento/ubuntu-24.04
## Rocky linux Image https://portal.cloud.hashicorp.com/vagrant/discover/rockylinux
BOX_IMAGE = "bento/ubuntu-24.04"
BOX_VERSION = "202502.21.0"

Vagrant.configure("2") do |config|
#-ControlPlane Node
    config.vm.define "k8s-ctr" do |subconfig|
      subconfig.vm.box = BOX_IMAGE
      subconfig.vm.box_version = BOX_VERSION
      subconfig.vm.provider "virtualbox" do |vb|
        vb.customize ["modifyvm", :id, "--groups", "/Cilium-Lab"]
        vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
        vb.name = "k8s-ctr"
        vb.cpus = 2
        vb.memory = 2048
        vb.linked_clone = true
      end
      subconfig.vm.host_name = "k8s-ctr"
      subconfig.vm.network "private_network", ip: "192.168.10.100"
      subconfig.vm.network "forwarded_port", guest: 22, host: 60000, auto_correct: true, id: "ssh"
      subconfig.vm.synced_folder "./", "/vagrant", disabled: true
      subconfig.vm.provision "shell", path: "https://raw.githubusercontent.com/gasida/vagrant-lab/refs/heads/main/cilium-study/1w/init_cfg.sh", args: [ K8SV, CONTAINERDV]
      subconfig.vm.provision "shell", path: "https://raw.githubusercontent.com/gasida/vagrant-lab/refs/heads/main/cilium-study/1w/k8s-ctr.sh", args: [ N ]
    end

#-Worker Nodes Subnet1
  (1..N).each do |i|
    config.vm.define "k8s-w#{i}" do |subconfig|
      subconfig.vm.box = BOX_IMAGE
      subconfig.vm.box_version = BOX_VERSION
      subconfig.vm.provider "virtualbox" do |vb|
        vb.customize ["modifyvm", :id, "--groups", "/Cilium-Lab"]
        vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
        vb.name = "k8s-w#{i}"
        vb.cpus = 2
        vb.memory = 1536
        vb.linked_clone = true
      end
      subconfig.vm.host_name = "k8s-w#{i}"
      subconfig.vm.network "private_network", ip: "192.168.10.10#{i}"
      subconfig.vm.network "forwarded_port", guest: 22, host: "6000#{i}", auto_correct: true, id: "ssh"
      subconfig.vm.synced_folder "./", "/vagrant", disabled: true
      subconfig.vm.provision "shell", path: "https://raw.githubusercontent.com/gasida/vagrant-lab/refs/heads/main/cilium-study/1w/init_cfg.sh", args: [ K8SV, CONTAINERDV]
      subconfig.vm.provision "shell", path: "https://raw.githubusercontent.com/gasida/vagrant-lab/refs/heads/main/cilium-study/1w/k8s-w.sh"
    end
  end

end

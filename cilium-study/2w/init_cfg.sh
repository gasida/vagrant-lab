#!/usr/bin/env bash

echo ">>>> Initial Config Start <<<<"

echo "[TASK 1] Setting Profile & Bashrc"
echo 'alias vi=vim' >> /etc/profile
echo "sudo su -" >> /home/vagrant/.bashrc
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime # Change Timezone


echo "[TASK 2] Disable AppArmor"
systemctl stop ufw && systemctl disable ufw >/dev/null 2>&1
systemctl stop apparmor && systemctl disable apparmor >/dev/null 2>&1


echo "[TASK 3] Disable and turn off SWAP"
swapoff -a && sed -i '/swap/s/^/#/' /etc/fstab


echo "[TASK 4] Install Packages"
apt update -qq >/dev/null 2>&1
apt-get install apt-transport-https ca-certificates curl gpg -y -qq >/dev/null 2>&1

# Download the public signing key for the Kubernetes package repositories.
mkdir -p -m 755 /etc/apt/keyrings
K8SMMV=$(echo $1 | sed -En 's/^([0-9]+\.[0-9]+)\..*/\1/p')
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8SMMV/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8SMMV/deb/ /" >> /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# packets traversing the bridge are processed by iptables for filtering
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf

# enable br_netfilter for iptables 
modprobe br_netfilter
modprobe overlay
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
echo "overlay" >> /etc/modules-load.d/k8s.conf


echo "[TASK 5] Install Kubernetes components (kubeadm, kubelet and kubectl)"
# Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version
apt update >/dev/null 2>&1

# apt list -a kubelet ; apt list -a containerd.io
apt-get install -y kubelet=$1 kubectl=$1 kubeadm=$1 containerd.io=$2 >/dev/null 2>&1
apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1

# containerd configure to default and cgroup managed by systemd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# avoid WARN&ERRO(default endpoints) when crictl run  
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF

# ready to install for k8s 
systemctl restart containerd && systemctl enable containerd
systemctl enable --now kubelet


echo "[TASK 6] Install Packages & Helm"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y bridge-utils sshpass net-tools conntrack ngrep tcpdump ipset arping wireguard jq tree bash-completion unzip kubecolor termshark >/dev/null 2>&1
curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash >/dev/null 2>&1


echo ">>>> Initial Config End <<<<"

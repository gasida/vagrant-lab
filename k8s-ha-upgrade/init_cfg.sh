#!/usr/bin/env bash

echo ">>>> Initial Config Start <<<<"


echo "[TASK 1] Change Timezone and Enable NTP"
timedatectl set-local-rtc 0
timedatectl set-timezone Asia/Seoul


echo "[TASK 2] Disable firewalld and selinux"
systemctl disable --now firewalld >/dev/null 2>&1
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config


echo "[TASK 3] Disable and turn off SWAP & Delete swap partitions"
swapoff -a
sed -i '/swap/d' /etc/fstab
sfdisk --delete /dev/sda 2 >/dev/null 2>&1
partprobe /dev/sda >/dev/null 2>&1


echo "[TASK 4] Config kernel & module"
cat << EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay >/dev/null 2>&1
modprobe br_netfilter >/dev/null 2>&1

cat << EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1


echo "[TASK 5] Setting Local DNS Using Hosts file"
sed -i '/^127\.0\.\(1\|2\)\.1/d' /etc/hosts
cat << EOF >> /etc/hosts
192.168.10.11 k8s-ctr1
192.168.10.12 k8s-ctr2
192.168.10.13 k8s-ctr3
192.168.10.101 k8s-w1
192.168.10.102 k8s-w2
EOF


echo "[TASK 6] Delete default routing - enp0s9 NIC" # setenforce 0 설정 필요
nmcli connection modify enp0s9 ipv4.never-default yes
nmcli connection up enp0s9 >/dev/null 2>&1


echo "[TASK 7] Install Containerd"
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
dnf install -y -q containerd.io-2.1.5-1.el10
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl daemon-reload
systemctl enable --now containerd >/dev/null 2>&1


echo "[TASK 8] Install kubeadm kubelet kubectl"
cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
dnf install -y -q kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet >/dev/null 2>&1

cat << EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF

NODEIP=$(ip -4 addr show enp0s9 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
cat << EOF > /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--node-ip=$NODEIP"
EOF


echo "[TASK 9] Install nfs-utils"
dnf install -y -q nfs-utils >/dev/null 2>&1


echo ">>>> Initial Config End <<<<"

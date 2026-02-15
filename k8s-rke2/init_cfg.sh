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
#vxlan
EOF
modprobe overlay >/dev/null 2>&1
modprobe br_netfilter >/dev/null 2>&1
#modprobe vxlan >/dev/null 2>&1

cat << EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1


echo "[TASK 5] Setting Local DNS Using Hosts file"
sed -i '/^127\.0\.\(1\|2\)\.1/d' /etc/hosts
for (( i=1; i<=$1; i++  )); do echo "192.168.10.1$i k8s-node$i" >> /etc/hosts; done


echo "[TASK 6] Install Helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION=v3.20.0 bash >/dev/null 2>&1
# echo "[TASK 6] Delete default routing - enp0s9 NIC" # setenforce 0 설정 필요
# nmcli connection modify enp0s9 ipv4.never-default yes
# nmcli connection up enp0s9 >/dev/null 2>&1


echo "[TASK 7] Setting SSHD"
#echo "root:qwe123" | chpasswd

cat << EOF >> /etc/ssh/sshd_config
PermitRootLogin yes
PasswordAuthentication yes
EOF
systemctl restart sshd >/dev/null 2>&1


echo "[TASK 8] Install packages"
dnf install -y conntrack python3-pip git >/dev/null 2>&1


echo "[TASK 9] NetworkManager to ignore calico/flannel related network interfaces"
# https://docs.rke2.io/known_issues#networkmanager
cat << EOF > /etc/NetworkManager/conf.d/k8s.conf
[keyfile]
unmanaged-devices=interface-name:flannel*;interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
EOF
systemctl reload NetworkManager


echo "[TASK 11] Install K9s"
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
wget -P /tmp https://github.com/derailed/k9s/releases/latest/download/k9s_linux_${CLI_ARCH}.tar.gz  >/dev/null 2>&1
tar -xzf /tmp/k9s_linux_${CLI_ARCH}.tar.gz -C /tmp
chown root:root /tmp/k9s
mv /tmp/k9s /usr/local/bin/
chmod +x /usr/local/bin/k9s


echo "[TASK 12] ETC"
echo "sudo su -" >> /home/vagrant/.bashrc


echo ">>>> Initial Config End <<<<"

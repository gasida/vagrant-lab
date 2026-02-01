#!/usr/bin/env bash

echo ">>>> Initial Config Start <<<<"


echo "[TASK 1] Change Timezone and Enable NTP"
timedatectl set-local-rtc 0
timedatectl set-timezone Asia/Seoul


echo "[TASK 2] Disable firewalld and selinux"
systemctl disable --now firewalld >/dev/null 2>&1
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config


echo "[TASK 3] Setting Local DNS Using Hosts file"
sed -i '/^127\.0\.\(1\|2\)\.1/d' /etc/hosts
echo "192.168.10.10 k8s-api-srv.admin-lb.com admin-lb" >> /etc/hosts
for (( i=1; i<=$1; i++  )); do echo "192.168.10.1$i k8s-node$i" >> /etc/hosts; done


echo "[TASK 4] Delete default routing - enp0s9 NIC" # setenforce 0 설정 필요
nmcli connection modify enp0s9 ipv4.never-default yes
nmcli connection up enp0s9 >/dev/null 2>&1


echo "[TASK 5] Install kubectl"
cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
exclude=kubectl
EOF
dnf install -y -q kubectl --disableexcludes=kubernetes >/dev/null 2>&1


echo "[TASK 6] Install HAProxy"
dnf install -y haproxy >/dev/null 2>&1

cat << EOF > /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

    # utilize system-wide crypto-policies
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  tcplog
    option                  dontlognull
    option http-server-close
    #option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

# ---------------------------------------------------------------------
# Kubernetes API Server Load Balancer Configuration
# ---------------------------------------------------------------------
frontend k8s-api
    bind *:6443
    mode tcp
    option tcplog
    default_backend k8s-api-backend

backend k8s-api-backend
    mode tcp
    option tcp-check
    option log-health-checks
    timeout client 3h
    timeout server 3h
    balance roundrobin
    server k8s-node1 192.168.10.11:6443 check check-ssl verify none inter 10000
    server k8s-node2 192.168.10.12:6443 check check-ssl verify none inter 10000
    server k8s-node3 192.168.10.13:6443 check check-ssl verify none inter 10000

# ---------------------------------------------------------------------
# HAProxy Stats Dashboard - http://192.168.10.10:9000/haproxy_stats
# ---------------------------------------------------------------------
listen stats
    bind *:9000
    mode http
    stats enable
    stats uri /haproxy_stats
    stats realm HAProxy\ Statistic
    stats admin if TRUE

# ---------------------------------------------------------------------
# Configure the Prometheus exporter - curl http://192.168.10.10:8405/metrics
# ---------------------------------------------------------------------
frontend prometheus
    bind *:8405
    mode http
    http-request use-service prometheus-exporter if { path /metrics }
    no log
EOF
systemctl enable --now haproxy >/dev/null 2>&1


echo "[TASK 7] Install nfs-utils"
dnf install -y nfs-utils >/dev/null 2>&1
systemctl enable --now nfs-server >/dev/null 2>&1
mkdir -p /srv/nfs/share
chown nobody:nobody /srv/nfs/share
chmod 755 /srv/nfs/share
echo '/srv/nfs/share *(rw,async,no_root_squash,no_subtree_check)' > /etc/exports
exportfs -rav


echo "[TASK 8] Install packages"
dnf install -y python3-pip git sshpass >/dev/null 2>&1


echo "[TASK 9] Setting SSHD"
echo "root:qwe123" | chpasswd

cat << EOF >> /etc/ssh/sshd_config
PermitRootLogin yes
PasswordAuthentication yes
EOF
systemctl restart sshd >/dev/null 2>&1


echo "[TASK 10] Setting SSH Key"
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa >/dev/null 2>&1

sshpass -p 'qwe123' ssh-copy-id -o StrictHostKeyChecking=no root@192.168.10.10  >/dev/null 2>&1  # cat /root/.ssh/authorized_keys
for (( i=1; i<=$1; i++  )); do sshpass -p 'qwe123' ssh-copy-id -o StrictHostKeyChecking=no root@192.168.10.1$i >/dev/null 2>&1 ; done

ssh -o StrictHostKeyChecking=no root@admin-lb hostname >/dev/null 2>&1
for (( i=1; i<=$1; i++  )); do sshpass -p 'qwe123' ssh -o StrictHostKeyChecking=no root@k8s-node$i hostname >/dev/null 2>&1 ; done


echo "[TASK 11] Clone Kubespray Repository"
git clone -b v2.29.1 https://github.com/kubernetes-sigs/kubespray.git /root/kubespray >/dev/null 2>&1

cp -rfp /root/kubespray/inventory/sample /root/kubespray/inventory/mycluster
cat << EOF > /root/kubespray/inventory/mycluster/inventory.ini
[kube_control_plane]
k8s-node1 ansible_host=192.168.10.11 ip=192.168.10.11 etcd_member_name=etcd1
k8s-node2 ansible_host=192.168.10.12 ip=192.168.10.12 etcd_member_name=etcd2
k8s-node3 ansible_host=192.168.10.13 ip=192.168.10.13 etcd_member_name=etcd3

[etcd:children]
kube_control_plane

[kube_node]
k8s-node4 ansible_host=192.168.10.14 ip=192.168.10.14
#k8s-node5 ansible_host=192.168.10.15 ip=192.168.10.15
EOF


echo "[TASK 12] Install Python Dependencies"
pip3 install -r /root/kubespray/requirements.txt >/dev/null 2>&1 # pip3 list


echo "[TASK 13] Install K9s"
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
wget -P /tmp https://github.com/derailed/k9s/releases/latest/download/k9s_linux_${CLI_ARCH}.tar.gz  >/dev/null 2>&1
tar -xzf /tmp/k9s_linux_${CLI_ARCH}.tar.gz -C /tmp
chown root:root /tmp/k9s
mv /tmp/k9s /usr/local/bin/
chmod +x /usr/local/bin/k9s


echo "[TASK 14] Install kubecolor"
dnf install -y -q 'dnf-command(config-manager)' >/dev/null 2>&1
dnf config-manager --add-repo https://kubecolor.github.io/packages/rpm/kubecolor.repo >/dev/null 2>&1
dnf install -y -q kubecolor >/dev/null 2>&1


echo "[TASK 15] Install Helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION=v3.18.6 bash >/dev/null 2>&1


echo "[TASK 16] ETC"
echo "sudo su -" >> /home/vagrant/.bashrc


echo ">>>> Initial Config End <<<<"

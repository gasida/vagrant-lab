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
cat << EOF >> /etc/hosts
192.168.10.11 k8s-ctr1
192.168.10.12 k8s-ctr2
192.168.10.13 k8s-ctr3
EOF


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
    balance roundrobin
    server k8s-ctr1 192.168.10.11:6443 check
    server k8s-ctr2 192.168.10.12:6443 check
    server k8s-ctr3 192.168.10.13:6443 check

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
systemctl enable --now haproxy


echo "[TASK 7] Install nfs-utils"
dnf install -y nfs-utils >/dev/null 2>&1
systemctl enable --now nfs-server
mkdir -p /srv/nfs/share
chown nobody:nobody /srv/nfs/share
chmod 755 /srv/nfs/share
echo '/srv/nfs/share *(rw,async,no_root_squash,no_subtree_check)' > /etc/exports
exportfs -rav


echo "sudo su -" >> /home/vagrant/.bashrc

echo ">>>> Initial Config End <<<<"

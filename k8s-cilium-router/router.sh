#!/usr/bin/env bash

echo ">>>> Initial Config Start <<<<"

echo "[TASK 1] Setting Profile & Bashrc"
echo 'alias vi=vim' >> /etc/profile
echo "sudo su -" >> /home/vagrant/.bashrc
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

echo "[TASK 2] Disable AppArmor"
systemctl stop ufw && systemctl disable ufw >/dev/null 2>&1
systemctl stop apparmor && systemctl disable apparmor >/dev/null 2>&1

echo "[TASK 3] Add Kernel setting - IP Forwarding"
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p >/dev/null 2>&1

echo "[TASK 4] Setting Dummy Interface"
modprobe dummy
ip link add loop1 type dummy
ip link set loop1 up
ip addr add 192.168.200.254/24 dev loop1

echo "[TASK 5] Install Packages"
export DEBIAN_FRONTEND=noninteractive
apt update -qq >/dev/null 2>&1
apt-get install net-tools jq tree ngrep tcpdump frr termshark arping -y -qq >/dev/null 2>&1

echo "[TASK 6] Configure FRR"
sed -i "s/^bgpd=no/bgpd=yes/g" /etc/frr/daemons
systemctl daemon-reexec >/dev/null 2>&1
systemctl restart frr >/dev/null 2>&1
systemctl enable frr >/dev/null 2>&1

echo "[TASK 7] Install Apache"
apt install apache2 -y >/dev/null 2>&1
echo -e "<h1>Web Server : $(hostname)</h1>" > /var/www/html/index.html

echo ">>>> Initial Config End <<<<"

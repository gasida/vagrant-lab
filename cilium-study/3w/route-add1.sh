#!/usr/bin/env bash

echo ">>>> Route Add Config Start <<<<"

chmod 600 /etc/netplan/01-netcfg.yaml
chmod 600 /etc/netplan/50-vagrant.yaml

cat <<EOT>> /etc/netplan/50-vagrant.yaml
      routes:
      - to: 10.10.0.0/16
        via: 192.168.10.200
EOT

netplan apply

echo ">>>> Route Add Config End <<<<"
#!/usr/bin/env bash

echo ">>>> K8S Node config Start <<<<"

echo "[TASK 1] K8S Controlplane Join" 
kubeadm join --token 123456.1234567890123456 --discovery-token-unsafe-skip-ca-verification 192.168.10.100:6443  >/dev/null 2>&1

echo "[TASK 2] Change Node IP - eth1"
NODEIP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
sed -i "s/^\(KUBELET_KUBEADM_ARGS=\"\)/\1--node-ip=${NODEIP} /" /var/lib/kubelet/kubeadm-flags.env
systemctl daemon-reexec && systemctl restart kubelet

echo ">>>> K8S Node config End <<<<"

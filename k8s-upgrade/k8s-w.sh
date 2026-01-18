#!/usr/bin/env bash

echo ">>>> K8S Node config Start <<<<"


echo "[TASK 1] K8S Controlplane Join"
NODEIP=$(ip -4 addr show enp0s9 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
cat << EOF > kubeadm-join.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
discovery:
  bootstrapToken:
    token: "123456.1234567890123456"
    apiServerEndpoint: "192.168.10.100:6443"
    unsafeSkipCAVerification: true
nodeRegistration:
  criSocket: "unix:///run/containerd/containerd.sock"
  kubeletExtraArgs:
    - name: node-ip
      value: "$NODEIP"
EOF
kubeadm join --config="kubeadm-join.yaml"


echo "sudo su -" >> /home/vagrant/.bashrc

echo ">>>> K8S Node config End <<<<"

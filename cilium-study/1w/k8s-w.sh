#!/usr/bin/env bash

echo ">>>> K8S Node config Start <<<<"

echo "[TASK 1] K8S Controlplane Join" 
kubeadm join --token 123456.1234567890123456 --discovery-token-unsafe-skip-ca-verification 192.168.10.100:6443  >/dev/null 2>&1


echo ">>>> K8S Node config End <<<<"

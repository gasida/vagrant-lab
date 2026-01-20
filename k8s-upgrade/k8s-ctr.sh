#!/usr/bin/env bash

echo ">>>> K8S Controlplane config Start <<<<"


echo "[TASK 1] Initial Kubernetes"
cat << EOF > kubeadm-init.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
bootstrapTokens:
- token: "123456.1234567890123456"
  ttl: "0s"
  usages:
  - signing
  - authentication
nodeRegistration:
  kubeletExtraArgs:
    - name: node-ip
      value: "192.168.10.100"
  criSocket: "unix:///run/containerd/containerd.sock"
localAPIEndpoint:
  advertiseAddress: "192.168.10.100"
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "1.32.11"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
controllerManager:
  extraArgs:
    - name: "bind-address"
      value: "0.0.0.0"
scheduler:
  extraArgs:
    - name: "bind-address"
      value: "0.0.0.0"
etcd:
  local:
    extraArgs:
      - name: "listen-metrics-urls"
        value: "http://127.0.0.1:2381,http://192.168.10.100:2381"
EOF
kubeadm init --config="kubeadm-init.yaml"


echo "[TASK 2] Setting kube config file"
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config


echo "[TASK 3] Install Helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION=v3.18.6 bash >/dev/null 2>&1


echo "[TASK 4] Install kubecolor"
dnf install -y -q 'dnf-command(config-manager)' >/dev/null 2>&1
dnf config-manager --add-repo https://kubecolor.github.io/packages/rpm/kubecolor.repo >/dev/null 2>&1
dnf install -y -q kubecolor >/dev/null 2>&1


echo "[TASK 5] Install Kubectx & Kubens"
dnf install -y -q git >/dev/null 2>&1
git clone https://github.com/ahmetb/kubectx /opt/kubectx >/dev/null 2>&1
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx


echo "[TASK 6] Install Kubeps & Setting PS1"
git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1 >/dev/null 2>&1
cat << "EOT" >> /root/.bash_profile
source /root/kube-ps1/kube-ps1.sh
KUBE_PS1_SYMBOL_ENABLE=true
function get_cluster_short() {
  echo "$1" | cut -d . -f1
}
KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
KUBE_PS1_SUFFIX=') '
PS1='$(kube_ps1)'$PS1
EOT
kubectl config rename-context "kubernetes-admin@kubernetes" "HomeLab" >/dev/null 2>&1


echo "[TASK 7] Install Flannel CNI"
/usr/local/bin/helm repo add flannel https://flannel-io.github.io/flannel >/dev/null 2>&1
kubectl create namespace kube-flannel >/dev/null 2>&1
cat << EOF > flannel.yaml
podCidr: "10.244.0.0/16"
flannel:
  cniBinDir: "/opt/cni/bin"
  cniConfDir: "/etc/cni/net.d"
  args:
  - "--ip-masq"
  - "--kube-subnet-mgr"
  - "--iface=enp0s9"  
  backend: "vxlan"
EOF
/usr/local/bin/helm install flannel flannel/flannel --namespace kube-flannel --version 0.27.3 -f flannel.yaml >/dev/null 2>&1


echo "[TASK 8] Source the completion"
echo 'source <(kubectl completion bash)' >> /etc/profile
echo 'source <(kubeadm completion bash)' >> /etc/profile


echo "[TASK 9] Alias kubectl to k"
echo 'alias k=kubectl' >> /etc/profile
echo 'alias kc=kubecolor' >> /etc/profile
echo 'complete -o default -F __start_kubectl k' >> /etc/profile


echo "[TASK 10] Install Metrics-server"
/usr/local/bin/helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/  >/dev/null 2>&1
/usr/local/bin/helm upgrade --install metrics-server metrics-server/metrics-server --set 'args[0]=--kubelet-insecure-tls' -n kube-system  >/dev/null 2>&1


echo "sudo su -" >> /home/vagrant/.bashrc

echo ">>>> K8S Controlplane Config End <<<<"
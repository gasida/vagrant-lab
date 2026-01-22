#!/usr/bin/env bash

echo ">>>> K8S Controlplane config Start <<<<"


echo "[TASK 1] Install Helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION=v3.18.6 bash >/dev/null 2>&1


echo "[TASK 2] Install kubecolor"
dnf install -y -q 'dnf-command(config-manager)' >/dev/null 2>&1
dnf config-manager --add-repo https://kubecolor.github.io/packages/rpm/kubecolor.repo >/dev/null 2>&1
dnf install -y -q kubecolor >/dev/null 2>&1


echo "[TASK 3] Install Kubectx & Kubens"
dnf install -y -q git >/dev/null 2>&1
git clone https://github.com/ahmetb/kubectx /opt/kubectx >/dev/null 2>&1
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx


echo "[TASK 4] Install Kubeps & Setting PS1"
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


echo "[TASK 5] Source the completion"
echo 'source <(kubectl completion bash)' >> /etc/profile
echo 'source <(kubeadm completion bash)' >> /etc/profile


echo "[TASK 6] Alias kubectl to k"
echo 'alias k=kubectl' >> /etc/profile
echo 'alias kc=kubecolor' >> /etc/profile
echo 'complete -o default -F __start_kubectl k' >> /etc/profile


echo "[TASK 7] Install etcdctl"
ETCD_VER=3.5.24
ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then ARCH=arm64; fi
curl -L https://github.com/etcd-io/etcd/releases/download/v${ETCD_VER}/etcd-v${ETCD_VER}-linux-${ARCH}.tar.gz -o /tmp/etcd-v${ETCD_VER}.tar.gz >/dev/null 2>&1
mkdir -p /tmp/etcd-download
tar xzvf /tmp/etcd-v${ETCD_VER}.tar.gz -C /tmp/etcd-download --strip-components=1 >/dev/null 2>&1
mv /tmp/etcd-download/etcdctl /usr/local/bin/
mv /tmp/etcd-download/etcdutl /usr/local/bin/
chown root:root /usr/local/bin/etcdctl
chown root:root /usr/local/bin/etcdutl


echo "sudo su -" >> /home/vagrant/.bashrc

echo ">>>> K8S Controlplane Config End <<<<"
#!/usr/bin/env bash

echo ">>>> K8S Controlplane config Start <<<<"

echo "[TASK 1] Initial Kubernetes"
curl --silent -o /root/kubeadm-init-ctr-config.yaml https://raw.githubusercontent.com/gasida/vagrant-lab/refs/heads/main/cilium-study/kubeadm-init-ctr-config.yaml
K8SMMV=$(echo $3 | sed -En 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
sed -i "s/K8S_VERSION_PLACEHOLDER/v${K8SMMV}/g" /root/kubeadm-init-ctr-config.yaml
kubeadm init --config="/root/kubeadm-init-ctr-config.yaml"  >/dev/null 2>&1


echo "[TASK 2] Setting kube config file"
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config


echo "[TASK 3] Source the completion"
echo 'source <(kubectl completion bash)' >> /etc/profile
echo 'source <(kubeadm completion bash)' >> /etc/profile


echo "[TASK 4] Alias kubectl to k"
echo 'alias k=kubectl' >> /etc/profile
echo 'alias kc=kubecolor' >> /etc/profile
echo 'complete -F __start_kubectl k' >> /etc/profile


echo "[TASK 5] Install Kubectx & Kubens"
git clone https://github.com/ahmetb/kubectx /opt/kubectx >/dev/null 2>&1
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx


echo "[TASK 6] Install Kubeps & Setting PS1"
git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1 >/dev/null 2>&1
cat <<"EOT" >> /root/.bash_profile
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


echo "[TASK 7] Install Cilium CNI"
NODEIP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1
helm repo update >/dev/null 2>&1
helm install cilium cilium/cilium --version $2 --namespace kube-system \
--set k8sServiceHost=192.168.10.100 --set k8sServicePort=6443 \
--set ipam.mode="cluster-pool" --set ipam.operator.clusterPoolIPv4PodCIDRList={"172.20.0.0/16"} --set ipv4NativeRoutingCIDR=172.20.0.0/16 \
--set routingMode=native --set autoDirectNodeRoutes=true \
--set kubeProxyReplacement=true --set bpf.masquerade=true --set installNoConntrackIptablesRules=true \
--set endpointHealthChecking.enabled=false --set healthChecking=false \
--set hubble.enabled=true --set hubble.relay.enabled=true --set hubble.ui.enabled=true \
--set hubble.ui.service.type=NodePort --set hubble.ui.service.nodePort=30003 \
--set prometheus.enabled=true --set operator.prometheus.enabled=true --set hubble.metrics.enableOpenMetrics=true \
--set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}" \
--set operator.replicas=1 --set debug.enabled=true >/dev/null 2>&1


echo "[TASK 8] Install Cilium / Hubble CLI"
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz >/dev/null 2>&1
tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz >/dev/null 2>&1
tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz


echo "[TASK 9] Remove node taint"
kubectl taint nodes k8s-ctr node-role.kubernetes.io/control-plane-


echo "[TASK 10] local DNS with hosts file"
echo "192.168.10.100 k8s-ctr" >> /etc/hosts
echo "192.168.10.200 router" >> /etc/hosts
echo "192.168.20.100 k8s-w0" >> /etc/hosts
for (( i=1; i<=$1; i++  )); do echo "192.168.10.10$i k8s-w$i" >> /etc/hosts; done


echo "[TASK 11] Dynamically provisioning persistent local storage with Kubernetes"
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml >/dev/null 2>&1
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null 2>&1


echo "[TASK 12] Install Prometheus & Grafana"
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.18.0/examples/kubernetes/addons/prometheus/monitoring-example.yaml >/dev/null 2>&1
kubectl patch svc -n cilium-monitoring prometheus -p '{"spec": {"type": "NodePort", "ports": [{"port": 9090, "targetPort": 9090, "nodePort": 30001}]}}' >/dev/null 2>&1
kubectl patch svc -n cilium-monitoring grafana -p '{"spec": {"type": "NodePort", "ports": [{"port": 3000, "targetPort": 3000, "nodePort": 30002}]}}' >/dev/null 2>&1

# echo "[TASK 12] Install Prometheus Stack"
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts  >/dev/null 2>&1
# cat <<EOT > monitor-values.yaml
# prometheus:
#   prometheusSpec:
#     scrapeInterval: "15s"
#     evaluationInterval: "15s"
#   service:
#     type: NodePort
#     nodePort: 30001

# grafana:
#   defaultDashboardsTimezone: Asia/Seoul
#   adminPassword: prom-operator
#   service:
#     type: NodePort
#     nodePort: 30002

# alertmanager:
#   enabled: false
# defaultRules:
#   create: false
# prometheus-windows-exporter:
#   prometheus:
#     monitor:
#       enabled: false
# EOT
# helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 75.15.1 \
#   -f monitor-values.yaml --create-namespace --namespace monitoring  >/dev/null 2>&1


echo "[TASK 13] Install Metrics-server"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/  >/dev/null 2>&1
helm upgrade --install metrics-server metrics-server/metrics-server --set 'args[0]=--kubelet-insecure-tls' -n kube-system  >/dev/null 2>&1


echo "[TASK 14] Install k9s"
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_${CLI_ARCH}.deb -O /tmp/k9s_linux_${CLI_ARCH}.deb  >/dev/null 2>&1
apt install /tmp/k9s_linux_${CLI_ARCH}.deb  >/dev/null 2>&1


echo ">>>> K8S Controlplane Config End <<<<"
#!/bin/bash
set -e

NODE_IP=$1
[ -z "$NODE_IP" ] && echo "First argument must be the node IP"

CLUSTER_TOKEN=$2
[ -z "$CLUSTER_TOKEN" ] && echo "Second argument must be the cluster init/join token"

# Using the actual IP instead of 127.0.0.1 for the hostname fixed kubectl logs and/or flannel networking
echo "$NODE_IP $HOSTNAME" | tee -a /etc/hosts
sed -i 's/127.*yolean/#\0/' /etc/hosts

# required by kubeadm
swapoff -a

### basically https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/

yum install -y docker
setenforce 0

systemctl enable docker && systemctl start docker
sysctl net.bridge.bridge-nf-call-iptables
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubelet kubeadm kubectl

### mess with hosts and addresses, leftovers from a struggle with Vagrant's eth0

getent hosts $NODE_IP | grep $NODE_IP | grep $HOSTNAME || {
  echo "Failed to match IP $NODE_IP to hostname $HOSTNAME"
  exit 1
}

NODE_NUM=0
NODE_IP_START=${NODE_IP:0:-1}
for N in 1 2 3; do
  HOST_IP="$NODE_IP_START$N"
  HOSTS_ENTRY="$HOST_IP yolean-k8s-$N"
  [ "$HOST_IP" == "$NODE_IP" ] && {
    NODE_NUM=$N
    HOSTS_ENTRY="$NODE_IP yolean-k8s-dummy-entry-for-this-node"
  }
  echo "$HOSTS_ENTRY" >> /etc/hosts
done

echo "${NODE_IP_START}1   kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local" >> /etc/hosts

[ $NODE_NUM -eq 0 ] && echo "Failed to identify this node's host entry. Have IP addresses changed?" && exit 1

echo "Node number is $NODE_NUM"

set -x
ip addr
ip route
# kubernetes migth make assumptions on interface based on default route
#ip route replace default via 192.168.38.1 dev eth1
set +x

### end of hosts and adressess mess, resume kubeadm

systemctl enable kubelet && systemctl start kubelet

if [ $NODE_NUM -eq 1 ]; then
  sed -i "s/#token#/$CLUSTER_TOKEN/" /vagrant/kubeadm-master.yml
  kubeadm init --config=/vagrant/kubeadm-master.yml
  export KUBECONFIG=/etc/kubernetes/admin.conf
  kubectl taint nodes --all node-role.kubernetes.io/master-
  FLANNEL_VERSION=v0.9.1
  curl -o /vagrant/kube-flannel.yml https://raw.githubusercontent.com/coreos/flannel/$FLANNEL_VERSION/Documentation/kube-flannel.yml
  # use the private interface, ideae from https://crondev.com/kubernetes-installation-kubeadm/
  sed -i.bak 's|"/opt/bin/flanneld",|"/opt/bin/flanneld", "--iface=eth1",|' /vagrant/kube-flannel.yml
  kubectl apply -f /vagrant/kube-flannel.yml
else
  kubeadm join --token="$CLUSTER_TOKEN" 192.168.38.11:6443
fi

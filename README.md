# kubeadm-vagrant

We've tried to make this setup as generic as possible. Some unevitable choices are documented below.

Run like so:
```bash
vagrant up
export KUBECONFIG=$(pwd)/kubeconfig.yml
vagrant ssh yolean-k8s-1 -c 'sudo cat /etc/kubernetes/admin.conf' > $KUBECONFIG
```

## CentOS

Any distro that kubeadm supports would be fine, but we did the initial setup for a customer running CentOS 7.3.

## Vagrant

The only local VM automation tool we had experience with.
It's actually a bit overkill for just running kubeadm,
and we had to find a workaround for adapter `eth0` always being NAT.

## Hosts files

No clear directions in [kubeadm](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/) docs so using trial and error we ended up with:

 * A record for the node's hostname mapping to the external IP, instead of default 127.0.0.1.
 * Added a record for all the names that `kubeadm init` report the self-signed cert to be generated for.
 * One record per other node.

## Flannel

We just happened to select Flannel for pod networking, gotta have one.

Initially services would not work. You'd get a response on the expected port only if addressing the node that the pod lived on.
That turned out to be because flannel by default binds to eth0, which is Vagrant's interface for ssh etc.
We found the flanneld flag `--iface=eth1` to change that.

## Schedulable master

We allow regular pods to be [scheduled](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#master-isolation) on the master.
This is so we can run a multi-node cluster on 2x4GB memory.

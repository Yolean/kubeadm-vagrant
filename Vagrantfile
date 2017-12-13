# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'securerandom'

random_string1 = SecureRandom.hex
random_string2 = SecureRandom.hex
cluster_init_token = "#{random_string1[0..5]}.#{random_string2[0..15]}"

NUM_NODES = 2
NODE_MEM = '4096'

Vagrant.configure('2') do |config|
  (1..NUM_NODES).each do |node_number|
    node_name = "yolean-k8s-#{node_number}"
    config.vm.define node_name do |node|

      node.vm.box = "centos/7"
      node.vm.box_version = "1706.02"

      node.vm.box_check_update = false

      node.vm.hostname = "#{node_name}"

      node_address = 10 + node_number
      node_ip = "192.168.38.#{node_address}"
      node.vm.network 'private_network', ip: "#{node_ip}"

      node.vm.provider 'virtualbox' do |vb|
        vb.memory = NODE_MEM
      end

      # required by kubeadm, needed at every start
      node.vm.provision "shell", inline: "swapoff -a", run: "always"

      node.vm.provision 'shell' do |s|
        s.args = [node_ip, cluster_init_token]
        s.path = 'setup.sh'
      end

    end
  end
end

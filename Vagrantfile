require "yaml"
settings = YAML.load_file "settings.yaml"

IP_SECTIONS = settings["network"]["control_ip"].match(/^([0-9.]+\.)([^.]+)$/)
# First 3 octets including the trailing dot:
IP_NW = IP_SECTIONS.captures[0]
# Last octet excluding all dots:
IP_START = Integer(IP_SECTIONS.captures[1])
NUM_WORKER_NODES = settings["nodes"]["workers"]["count"]

Vagrant.configure("2") do |config|
  config.vm.synced_folder settings["mount_path"], "/vagrant" 
  config.vm.provision "shell",
   env: {
     "IP_NW" => IP_NW, 
     "IP_START" => IP_START,
     "NUM_WORKER_NODES" => NUM_WORKER_NODES 
    },
    inline: <<-SHELL
    apt-get update -y
    echo "$IP_NW$((IP_START)) master-node" >> /etc/hosts
    for i in `seq 1 ${NUM_WORKER_NODES}`; do
      echo "$IP_NW$((IP_START+i)) worker-node0${i}" >> /etc/hosts
    done
  SHELL
  
  config.vm.box = "bento-ubuntu-22-04.box"
  config.vm.box_url = "file://./boxes/vbox-ubuntu/bento-ubuntu-22-04.box"
  config.ssh.private_key_path = ["./boxes/vbox-ubuntu/private_key"]  

  # K8S Master (Control Plane) VM
  config.vm.define "master" do |master|
    master.vm.hostname = "master-node"
    master.vm.network "private_network", ip: settings["network"]["control_ip"]
    # Port forwarding from host to master VM
    master.vm.network "forwarded_port", guest: 22, host: 30022
    master.vm.network "forwarded_port", guest: 3000, host: 33000
	  master.vm.network "forwarded_port", guest: 30909, host: 30909
	  master.vm.network "forwarded_port", guest: 30080, host: 30080
	  master.vm.network "forwarded_port", guest: 30001, host: 30001
	  master.vm.network "forwarded_port", guest: 30000, host: 30000
	  # Public network (uncomment to bridge to host NIC)
	  # master.vm.network "public_network", bridge: "eth0", use_dhcp_assigned_default_route: true
    if settings["shared_folders"]
      settings["shared_folders"].each do |shared_folder|
        master.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
      end
    end
    master.vm.provider "virtualbox" do |vb|
        vb.cpus = settings["nodes"]["control"]["cpu"]
        vb.memory = settings["nodes"]["control"]["memory"]
        if settings["cluster_name"] and settings["cluster_name"] != ""
          vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
        end
    end
    master.vm.provision "shell", privileged: false, name: "Dos2Unix", path: "dos2unix.sh"
    master.vm.provision "shell",
      env: {
        "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
        "ENVIRONMENT" => settings["environment"],
        "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
        "CRIO_VERSION" => settings["software"]["crio"],
        "OS" => settings["software"]["os"],
        "CONTROL_IP" => settings["network"]["control_ip"],
        "POD_CIDR" => settings["network"]["pod_cidr"],
        "SERVICE_CIDR" => settings["network"]["service_cidr"]
      },
      path: "provision/k8s/master/master_vm_provision.sh"
  end

  # K8S Worker Nodes
  (1..NUM_WORKER_NODES).each do |i|
    config.vm.define "node0#{i}" do |node|
      node.vm.hostname = "worker-node0#{i}"
      node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"

      # Public network (uncomment to bridge to host NIC)
	    # node.vm.network "public_network", bridge: "eth0", use_dhcp_assigned_default_route: true
      if settings["shared_folders"]
        settings["shared_folders"].each do |shared_folder|
          node.vm.synced_folder shared_folder["host_path"], shared_folder["vm_path"]
        end
      end
      node.vm.provider "virtualbox" do |vb|
          vb.cpus = settings["nodes"]["workers"]["cpu"]
          vb.memory = settings["nodes"]["workers"]["memory"]
          if settings["cluster_name"] and settings["cluster_name"] != ""
            vb.customize ["modifyvm", :id, "--groups", ("/" + settings["cluster_name"])]
          end
      end
      node.vm.provision "shell", privileged: false, name: "Dos2Unix", path: "dos2unix.sh"
      node.vm.provision "shell",
        env: {
          "DNS_SERVERS" => settings["network"]["dns_servers"].join(" "),
          "ENVIRONMENT" => settings["environment"],
          "KUBERNETES_VERSION" => settings["software"]["kubernetes"],
          "CRIO_VERSION" => settings["software"]["crio"],
          "OS" => settings["software"]["os"],
          "NODE_INDEX" => i.to_s
        },
        path: "provision/k8s/node/node_vm_provision.sh"
    end
  end
end
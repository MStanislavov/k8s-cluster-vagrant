# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Create and provision the full cluster (master + workers)
vagrant up

# SSH into the master node
vagrant ssh master

# Suspend cluster (preferred over halt  - preserves state)
vagrant suspend

# Resume from suspended state
vagrant up

# Restart sequence (order matters):
#   1. vagrant up master
#   2. Wait ~5 minutes for K8s services to stabilize
#   3. vagrant up  (starts workers)

# Destroy and recreate
vagrant destroy -f && vagrant up

# Run kubectl from master
vagrant ssh master -c "kubectl get nodes"
```

## Architecture

Vagrant + VirtualBox provisions a local Kubernetes cluster on Ubuntu 22.04:

- **1 master node** (`master-node`, 10.0.0.101) + **N worker nodes** (default 2, IPs incremented from .102)
- **Container runtime:** CRI-O (not Docker)
- **CNI:** Calico (v3.25.0) for pod networking
- **Storage:** NFS server on master, NFS clients on workers (`/var/nfs_share_dir`)
- **Package manager:** Helm (v3.5.2) pre-installed on master
- **Monitoring:** Metrics Server for resource metrics (enables `kubectl top`)
- **Config reloading:** Reloader (v1.0.72) watches ConfigMaps/Secrets and restarts affected workloads
- **Scheduling:** Master node taint removed  - pods can schedule on master

## Configuration

All cluster parameters are in `settings.yaml`:

- Node counts, CPU, memory
- K8s version, CRI-O version
- Network CIDRs (pod: `172.16.1.0/16`, service: `172.17.1.0/18`)
- DNS servers, proxy environment variables
- Optional shared folders and dashboard

The Vagrantfile reads `settings.yaml` and passes values as environment variables to provisioning scripts.

## Provisioning Flow

```
Vagrantfile
  ├─ dos2unix.sh (line-ending fix for Windows hosts)
  ├─ /etc/hosts populated on all nodes
  │
  ├─ Master node:
  │   └─ provision/k8s/master/master_vm_provision.sh
  │       ├─ provision/k8s/common/common.sh        (CRI-O, kubelet, kubeadm, kubectl)
  │       └─ provision/k8s/master/master.sh         (kubeadm init, Calico, Helm, NFS, Metrics Server)
  │           └─ provision/k8s/master/install-components.sh  (async: Reloader, cluster validation)
  │
  └─ Worker nodes:
      └─ provision/k8s/node/node_vm_provision.sh
          ├─ provision/k8s/common/common.sh
          └─ provision/k8s/node/node.sh             (kubeadm join via /vagrant/configs/join.sh)
```

The `configs/` directory is generated at runtime on the master and shared via `/vagrant` mount  - it contains `join.sh` (worker join command) and `config` (kubeconfig).

## Networking

- **Private network:** 10.0.0.0/24 (VirtualBox host-only)
- **Port forwarding from host:** 30022 (SSH), 33000 (3000), 30909, 30080, 30001, 30000
- **SSH:** user `root`/`vagrant`, password `vagrant`, or key at `boxes/vbox-ubuntu/private_key`

## Windows Host Notes

All shell scripts run inside Ubuntu VMs. The `dos2unix.sh` provisioner converts CRLF to LF on every script in the project before other provisioners run, so Windows line endings won't break anything.

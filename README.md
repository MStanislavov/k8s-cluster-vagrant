# Kubernetes Cluster with Vagrant

A fully automated local Kubernetes cluster provisioned with Vagrant and VirtualBox. Spins up a multi-node cluster (1 master + N workers) on Ubuntu 22.04 with CRI-O, Calico networking, Helm, NFS storage, and more. Ready to use in a single `vagrant up`.

## Architecture Diagram

```mermaid
graph TB
    subgraph HOST["Host Machine (Windows / Linux / macOS)"]
        direction TB
        VAGRANT["Vagrant + VirtualBox<br/><i>reads settings.yaml</i>"]
        PORTS["Port Forwarding<br/>localhost:30022 → master:22<br/>localhost:33000 → master:3000<br/>localhost:30080 → master:30080<br/>localhost:30909 → master:30909<br/>localhost:30001 → master:30001<br/>localhost:30000 → master:30000"]
        SHARED["/vagrant - project directory<br/>mounted on all VMs"]
    end

    subgraph NETWORK["Private Network  10.0.0.0/24"]
        direction LR

        subgraph MASTER["Master Node - 10.0.0.101<br/>master-node · 2 vCPU · 4 GB"]
            direction TB
            CP["Control Plane<br/>kube-apiserver<br/>kube-scheduler<br/>kube-controller-manager<br/>etcd"]
            COMPONENTS["Cluster Components<br/>Calico CNI v3.25.0<br/>Metrics Server<br/>Helm v3.5.2<br/>Reloader v1.0.72<br/>NFS Server"]
            MCRIO["CRI-O Runtime"]
            MNET["Pod CIDR 172.16.1.0/16<br/>Service CIDR 172.17.1.0/18<br/>NodePort Range 0-65535"]
        end

        subgraph W1["Worker Node 01 - 10.0.0.102<br/>worker-node01 · 2 vCPU · 4 GB"]
            direction TB
            W1K["kubelet · kube-proxy"]
            W1C["CRI-O Runtime · Calico"]
            W1N["NFS Client"]
        end

        subgraph W2["Worker Node 02 - 10.0.0.103<br/>worker-node02 · 2 vCPU · 4 GB"]
            direction TB
            W2K["kubelet · kube-proxy"]
            W2C["CRI-O Runtime · Calico"]
            W2N["NFS Client"]
        end
    end

    VAGRANT -->|provisions| MASTER
    VAGRANT -->|provisions| W1
    VAGRANT -->|provisions| W2
    MASTER -- "NFS /var/nfs_share_dir" --- W1
    MASTER -- "NFS /var/nfs_share_dir" --- W2
    MASTER -- "kubeadm join" --- W1
    MASTER -- "kubeadm join" --- W2

    style HOST fill:#2d2d2d,stroke:#555,color:#eee
    style NETWORK fill:#1a1a2e,stroke:#4a90d9,color:#eee
    style MASTER fill:#0d3b66,stroke:#4a90d9,color:#eee
    style W1 fill:#14453d,stroke:#3cb371,color:#eee
    style W2 fill:#14453d,stroke:#3cb371,color:#eee
    style CP fill:#1b4965,stroke:#62b6cb,color:#eee
    style COMPONENTS fill:#1b4965,stroke:#62b6cb,color:#eee
```

## Provisioning Flow

```mermaid
flowchart TD
    START["vagrant up"] --> ALLVMS["All VMs<br/>apt-get update · populate /etc/hosts"]
    ALLVMS --> DOS["dos2unix.sh<br/>Convert line endings for Windows hosts"]

    DOS --> COMMON_M["common.sh - Master"]
    DOS --> COMMON_W["common.sh - Workers"]

    subgraph COMMON["common.sh (runs on every node)"]
        direction TB
        C1["Disable UFW firewall"] --> C2["Disable swap"]
        C2 --> C3["Configure DNS servers"]
        C3 --> C4["install-crio.sh<br/>CRI-O container runtime"]
        C4 --> C5["install-k8s.sh<br/>kubelet · kubeadm · kubectl"]
    end

    COMMON_M --> COMMON
    COMMON_W --> COMMON

    COMMON -- master path --> MASTER_SH
    COMMON -- worker path --> NODE_SH

    subgraph MASTER_SH["master.sh"]
        direction TB
        M1["kubeadm init<br/>Initialize control plane"] --> M2["Export kubeconfig & join token<br/>to /vagrant/configs/"]
        M2 --> M3["Install Calico CNI"]
        M3 --> M4["Install Metrics Server & Helm"]
        M4 --> M5["Remove control-plane taint"]
        M5 --> M6["Expand NodePort range 0-65535"]
        M6 --> M7["Set up NFS server"]
        M7 --> M8["install-components.sh<br/><i>async: validate cluster, install Reloader</i>"]
    end

    subgraph NODE_SH["node.sh (each worker)"]
        direction TB
        N1["Install NFS client"] --> N2["Copy kubeconfig from /vagrant/configs/"]
        N2 --> N3["kubeadm join<br/>Register with master"]
        N3 --> N4["Label node as worker"]
    end

    style START fill:#4a90d9,stroke:#fff,color:#fff
    style COMMON fill:#1b4965,stroke:#62b6cb,color:#eee
    style MASTER_SH fill:#0d3b66,stroke:#4a90d9,color:#eee
    style NODE_SH fill:#14453d,stroke:#3cb371,color:#eee
```

## Prerequisites

- **VirtualBox** v7.0.6 or later
- **Vagrant** v2.4.0 or later
- **RAM**: 16 GB+ on the host (each VM uses ~4 GB)

## Setup

### 1. Clone the repository

```shell
git clone https://github.com/CodeMaster10000/k8s-cluster-vagrant.git
cd k8s-cluster-vagrant
```

### 2. Configure Vagrant home (optional)

Set the `VAGRANT_HOME` environment variable if you want Vagrant data stored in a custom location.

### 3. Download the base box

The Vagrant box (~1 GB) is hosted externally since it exceeds version control limits.

1. Navigate to `boxes/vbox-ubuntu/`
2. Download from: [Google Drive](https://drive.google.com/file/d/1scqAQ1FMp81kbWM_Y-8fxarW-1i1Xvj5/view?usp=sharing)
3. Ensure the file is at `boxes/vbox-ubuntu/bento-ubuntu-22-04.box`

### 4. Bring up the cluster

```shell
vagrant up
```

This provisions the master node first, then all worker nodes. The entire process takes several minutes depending on your hardware and network speed.

## Usage

### Access the cluster

**Option A - SSH via Vagrant:**
```shell
vagrant ssh master
kubectl get nodes
```

**Option B - SSH via PuTTY or any SSH client:**
- IP: `10.0.0.101`
- User: `root`
- Password: `vagrant`

### Verify the cluster

```shell
kubectl get nodes
kubectl get pods --all-namespaces
```

### Suspend the cluster (recommended over halt)

```shell
vagrant suspend
```

### Resume the cluster

```shell
vagrant up
```

### Destroy the cluster

```shell
vagrant destroy -f
```

## Restarting After a Host Reboot

When restarting VMs after the host machine has been rebooted:

1. Start the master first: `vagrant up master`
2. Wait ~5 minutes for the Kubernetes control plane to stabilize
3. Start the workers: `vagrant up`

If pods are not scheduling after a restart, try restarting the Calico pods:

```shell
kubectl delete pod -n kube-system -l k8s-app=calico-node
kubectl delete pod -n kube-system -l k8s-app=calico-kube-controllers
```

## Configuration

All cluster settings are centralized in **`settings.yaml`**:

| Setting | Default | Description |
|---|---|---|
| `nodes.workers.count` | `2` | Number of worker nodes |
| `nodes.*.cpu` | `2` | vCPUs per node |
| `nodes.*.memory` | `4144` | RAM (MB) per node |
| `network.control_ip` | `10.0.0.101` | Master node IP (workers increment from here) |
| `network.pod_cidr` | `172.16.1.0/16` | Pod network CIDR |
| `network.service_cidr` | `172.17.1.0/18` | Service network CIDR |
| `software.kubernetes` | `v1.29` | Kubernetes version |
| `software.crio` | `1.28` | CRI-O version |

## Project Structure

```
.
├── Vagrantfile                      # VM definitions and provisioning orchestration
├── settings.yaml                    # Cluster configuration (nodes, network, versions)
├── environment.properties           # Shared variables and console colors for scripts
├── dos2unix.sh                      # Line-ending conversion for Windows compatibility
├── boxes/vbox-ubuntu/               # Vagrant base box and SSH private key
├── configs/                         # Generated at runtime (kubeconfig, join token)
├── provision/
│   ├── k8s/
│   │   ├── common/
│   │   │   ├── common.sh            # Shared setup (firewall, swap, DNS)
│   │   │   ├── install-crio.sh      # CRI-O container runtime installation
│   │   │   └── install-k8s.sh       # kubelet, kubeadm, kubectl installation
│   │   ├── master/
│   │   │   ├── master_vm_provision.sh  # Master VM entry point
│   │   │   └── master.sh              # Control plane init, CNI, Helm, NFS
│   │   ├── node/
│   │   │   ├── node_vm_provision.sh    # Worker VM entry point
│   │   │   └── node.sh                # Cluster join and node labeling
│   │   └── components/
│   │       ├── install-components.sh   # Async component installer
│   │       └── reloader/reloader.yaml  # Reloader deployment manifest
│   └── config/
│       ├── error_handling.sh         # Shared error trap
│       ├── cluster-validation.sh     # Waits for kube-system pods to be ready
│       └── nfs/exports               # NFS export configuration
└── etc/useful-commands.txt           # Handy kubectl, helm, and CRI-O commands
```

## License

MIT License - see [LICENSE.txt](LICENSE.txt).

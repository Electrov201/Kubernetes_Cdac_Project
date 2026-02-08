# Kubernetes Cluster Setup - 8GB RAM Configuration

---

## 📋 Project Information

| **Attribute**       | **Details**                                                              |
|---------------------|--------------------------------------------------------------------------|
| **Platform**        | DevOps                                                                   |
| **Duration**        | 2 Months                                                                 |
| **Operating System**| Ubuntu Linux 22.04 LTS                                                   |
| **Orchestration**   | Kubernetes v1.29 (kubeadm)                                               |
| **Automation**      | Ansible 2.9+                                                             |
| **Storage**         | NFS Server (Ubuntu) with PV/PVC                                          |
| **Monitoring**      | Prometheus + Grafana (Resource-Optimized)                                |
| **Networking**      | Flannel CNI (Lightweight)                                                |
| **Sample Workload** | Nginx Web Server                                                         |

---

## 💻 Hardware Requirements (8GB RAM - Lab/Development)

> ℹ️ **8GB Configuration**: 3GB each for master, worker, and NFS server.

| **Node**        | **vCPU** | **RAM**   | **Disk**  | **Role**                              |
|-----------------|----------|-----------|-----------|---------------------------------------|
| k8s-master      | 2        | 3 GB      | 30 GB     | Control Plane + Worker (taint removed)|
| k8s-worker1     | 2        | 3 GB      | 30 GB     | Worker Node                           |
| nfs-server      | 1        | 2 GB      | 50 GB     | Ubuntu NFS Server                     |
| **Total**       | **5**    | **8 GB**  | **110 GB**|                                       |

> 💡 **Note**: Uses lightweight Ubuntu NFS server instead of TrueNAS (saves RAM).

---

## 🏗️ System Architecture (8GB - 2 Node Setup)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      KUBERNETES CLUSTER (8GB RAM OPTIMIZED)                      │
│                                                                                  │
│    ┌───────────────────────────────────────────────────────────────────────┐    │
│    │              MASTER NODE (Control Plane + Worker Workloads)            │    │
│    │                           [Taint Removed]                              │    │
│    │                                                                        │    │
│    │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │    │
│    │   │ API Server  │  │    etcd     │  │  Scheduler  │  │ Controller  │  │    │
│    │   │   :6443     │  │  :2379-2380 │  │   Manager   │  │   Manager   │  │    │
│    │   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │    │
│    │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                   │    │
│    │   │   Kubelet   │  │ Kube-proxy  │  │  Flannel    │   (CNI ~50MB)    │    │
│    │   │   :10250    │  │             │  │  :8472/UDP  │                   │    │
│    │   └─────────────┘  └─────────────┘  └─────────────┘                   │    │
│    │   ┌─────────────┐                                                     │    │
│    │   │ Containerd  │                                                     │    │
│    │   └─────────────┘                                                     │    │
│    └────────────────────────────────┬───────────────────────────────────────┘    │
│                                     │                                            │
│                          ┌──────────┴──────────┐                                 │
│                          │   Kubernetes API    │                                 │
│                          │   (Internal Network)│                                 │
│                          └──────────┬──────────┘                                 │
│                                     │                                            │
│    ┌────────────────────────────────┴────────────────────────────────────┐      │
│    │                         WORKER NODE 1                                │      │
│    │                                                                      │      │
│    │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │      │
│    │   │   Kubelet   │  │ Kube-proxy  │  │  Flannel    │                 │      │
│    │   │   :10250    │  │             │  │  :8472/UDP  │                 │      │
│    │   └─────────────┘  └─────────────┘  └─────────────┘                 │      │
│    │   ┌─────────────┐                                                    │      │
│    │   │ Containerd  │                                                    │      │
│    │   └─────────────┘                                                    │      │
│    │                                                                      │      │
│    └──────────────────────────────────────────────────────────────────────┘      │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   PROMETHEUS    │         │    GRAFANA      │         │     NGINX       │
│   (Monitoring)  │         │  (Dashboards)   │         │   (Workload)    │
│    :30090       │         │    :30300       │         │    :30080       │
│   [512Mi limit] │         │   [256Mi limit] │         │  [2 replicas]   │
└─────────────────┘         └─────────────────┘         └─────────────────┘
          │                           │                           │
          └───────────────────────────┼───────────────────────────┘
                                      │
                                      ▼
                        ┌─────────────────────────┐
                        │   TRUENAS NFS STORAGE   │
                        │                         │
                        │  /mnt/pool/kubernetes   │
                        │  ├── prometheus/        │
                        │  ├── grafana/           │
                        │  └── nginx/             │
                        │    (NFS PV/PVC)         │
                        └─────────────────────────┘
```

---

## 🔧 Technology Stack (8GB Optimized)

| **Component**       | **Technology**           | **Version** | **Notes for 8GB**                               |
|---------------------|--------------------------|-------------|--------------------------------------------------|
| Operating System    | Ubuntu Linux             | 22.04 LTS   | Base OS for all nodes                            |
| Container Runtime   | Containerd               | 1.7.x       | CRI-compliant, lightweight                       |
| Orchestration       | Kubernetes               | 1.29.x      | Container orchestration                          |
| Cluster Bootstrap   | kubeadm                  | 1.29.x      | Cluster initialization                           |
| Automation          | Ansible                  | 2.9+        | Infrastructure as Code                           |
| CNI Plugin          | **Flannel**              | Latest      | **~50MB RAM** (vs Calico ~200MB)                 |
| Metrics Collection  | Prometheus               | Latest      | **512Mi limit, 3-day retention**                 |
| Visualization       | Grafana                  | Latest      | **256Mi limit**                                  |
| Sample Application  | Nginx (Alpine)           | Latest      | **2 replicas, 64Mi limit each**                  |
| Runtime Security    | Falco (Optional)         | 0.37.x      | **256Mi limit, enable if resources permit**      |

---

## 🚀 Implementation Phases (8GB Setup - 4 Weeks)

### Phase 1: Infrastructure Preparation (Week 1)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Server Provisioning                   | Provision 2 Ubuntu 22.04 VMs (1 master + 1 worker)         |
| Network Configuration                 | Configure static IPs, DNS resolution, host entries         |
| SSH Key Setup                         | Generate and distribute SSH keys for Ansible               |
| Ansible Control Node Setup            | Install Ansible on control machine                         |
| Update Inventory                      | Configure `hosts.ini` with VM IPs                          |
| Update Variables                      | Configure `all.yml` with cluster settings                  |

### Phase 2: Kubernetes Cluster Deployment (Week 2)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Common Role Execution                 | Install containerd, kubelet, kubeadm, kubectl on all nodes |
| Security Role Execution               | Configure UFW firewall, harden SSH                         |
| Master Node Initialization            | Run `kubeadm init` with pod network CIDR                   |
| Install Flannel CNI                   | Deploy lightweight Flannel networking (~50MB RAM)          |
| Remove Master Taint                   | Allow master to run workloads (8GB optimization)           |
| Worker Node Join                      | Join worker using generated token                          |
| Cluster Verification                  | Verify both nodes show Ready status                        |

### Phase 3: Monitoring & Services Deployment (Week 3)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Create Monitoring Namespace           | Create `monitoring` namespace                              |
| Deploy Prometheus                     | Deploy resource-optimized Prometheus (512Mi limit)         |
| Deploy Grafana                        | Deploy resource-optimized Grafana (256Mi limit)            |
| Apply Storage Manifests               | Deploy NFS PV/PVC (optional for 8GB)                       |
| Apply Security Manifests              | Deploy Network Policies and RBAC                           |
| Deploy Nginx Application              | Deploy 2-replica Nginx with alpine image                   |
| Configure etcd Backup                 | Setup automated etcd backup cron job                       |

### Phase 4: Testing & Validation (Week 4)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Self-Healing Test                     | Delete pods and verify automatic recreation                |
| Monitoring Validation                 | Verify Prometheus scraping and Grafana dashboards          |
| Service Access Test                   | Access Nginx, Prometheus, Grafana via NodePorts            |
| Resource Monitoring                   | Verify RAM usage stays within 8GB budget                   |
| Security Validation                   | Test Network Policies and PSS enforcement                  |
| Documentation Review                  | Ensure all access URLs and credentials documented          |

### Phase Summary

```
Week 1: Infrastructure       Week 2: Kubernetes         Week 3: Services          Week 4: Testing
┌────────────────────┐      ┌────────────────────┐      ┌────────────────────┐    ┌────────────────────┐
│ • Provision 2 VMs  │      │ • Install K8s      │      │ • Deploy Prometheus│    │ • Self-healing     │
│ • Configure IPs    │ ───▶ │ • Init master      │ ───▶ │ • Deploy Grafana   │───▶│ • Load testing     │
│ • Setup SSH keys   │      │ • Join worker      │      │ • Deploy Nginx     │    │ • Verify resources │
│ • Install Ansible  │      │ • Install Flannel  │      │ • Apply security   │    │ • Documentation    │
└────────────────────┘      └────────────────────┘      └────────────────────┘    └────────────────────┘
```

---

## �📁 Project Directory Structure

```
kubernetes-cluster-project/
│
├── README.md                              # Project overview
│
├── ansible/                               # Ansible Automation
│   ├── inventory/
│   │   └── hosts.ini                      # Server inventory (2 nodes for 8GB)
│   │
│   ├── group_vars/
│   │   └── all.yml                        # Global variables (8GB optimized)
│   │
│   ├── roles/
│   │   ├── common/                        # Common setup for all nodes
│   │   │   ├── tasks/main.yml             # Prerequisites, containerd, kubelet
│   │   │   └── handlers/main.yml          # Service restart handlers
│   │   │
│   │   ├── k8s_master/                    # Control plane setup
│   │   │   ├── tasks/main.yml             # kubeadm init, Flannel CNI
│   │   │   └── handlers/main.yml          # Kubelet restart handler
│   │   │
│   │   ├── k8s_worker/                    # Worker node setup
│   │   │   └── tasks/main.yml             # Join cluster using token
│   │   │
│   │   └── security/                      # Security hardening
│   │       ├── tasks/main.yml             # Firewall, SSH hardening
│   │       └── handlers/main.yml          # SSH/Firewall restart handlers
│   │
│   └── site.yml                           # Main orchestration playbook
│
├── kubernetes/                            # Kubernetes Manifests
│   ├── monitoring/
│   │   ├── namespace.yaml                 # monitoring namespace
│   │   ├── prometheus.yaml                # Prometheus (resource-optimized)
│   │   └── grafana.yaml                   # Grafana (resource-optimized)
│   │
│   ├── storage/
│   │   ├── nfs-pv.yaml                    # NFS PersistentVolume
│   │   └── nfs-pvc.yaml                   # PersistentVolumeClaim
│   │
│   ├── nginx/
│   │   └── deployment.yaml                # Nginx (2 replicas, alpine image)
│   │
│   ├── security/
│   │   ├── network-policy.yaml            # Network policy rules
│   │   └── pss-rbac.yaml                  # PSS and RBAC configuration
│   │
│   └── falco/
│       └── falco.yaml                     # Falco DaemonSet (optional)
│
├── scripts/
│   └── etcd-backup.sh                     # etcd backup automation script
│
└── docs/
    ├── Kubernetes_8GB_Setup.md            # This document
    ├── Kubernetes_16GB_Setup.md           # Full setup documentation
    ├── Kubernetes_Cluster_Project_Document.md  # Complete reference
    └── setup_guide.md                     # Step-by-step setup guide
```

---

## 🔄 How the Project Works

### Deployment Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ANSIBLE DEPLOYMENT WORKFLOW                           │
│                                                                              │
│   ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│   │   PLAY 1:       │    │   PLAY 2:       │    │   PLAY 3:       │         │
│   │   Common Setup  │───▶│   Master Init   │───▶│   Worker Join   │         │
│   │   (all nodes)   │    │   (master only) │    │   (workers)     │         │
│   └─────────────────┘    └─────────────────┘    └─────────────────┘         │
│           │                      │                      │                    │
│           ▼                      ▼                      ▼                    │
│   • Disable swap         • kubeadm init         • Get join command          │
│   • Install containerd   • Install Flannel CNI  • Join cluster              │
│   • Install kubelet      • Remove master taint  • Verify node ready         │
│   • Configure firewall   • Generate join token                              │
│   • Apply security       • Setup etcd backup                                │
│                          • Apply PSS labels                                  │
│                                                                              │
│                    ┌─────────────────────────────┐                          │
│                    │   PLAY 4:                   │                          │
│                    │   Deploy Cluster Services   │                          │
│                    │   (on master)               │                          │
│                    └─────────────────────────────┘                          │
│                                │                                             │
│                                ▼                                             │
│                    • Wait for nodes ready                                   │
│                    • Apply storage manifests                                │
│                    • Apply monitoring manifests                             │
│                    • Apply nginx manifests                                  │
│                    • Apply security manifests                               │
│                    • Apply Falco (if enabled)                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Step-by-Step Execution

#### Step 1: Run the Main Playbook
```bash
cd ansible/
ansible-playbook -i inventory/hosts.ini site.yml
```

#### Step 2: What Each Role Does

| **Role**       | **Tasks Performed**                                                    |
|----------------|------------------------------------------------------------------------|
| `common`       | Disables swap, installs containerd, kubelet, kubeadm, kubectl          |
| `security`     | Configures UFW firewall, hardens SSH, sets file permissions            |
| `k8s_master`   | Runs kubeadm init, installs Flannel CNI, removes master taint          |
| `k8s_worker`   | Gets join command from master, joins the cluster                       |

#### Step 3: Kubernetes Manifests Deployment

After the cluster is ready, the playbook automatically deploys:

| **Component**   | **Manifest Location**                  | **Description**                     |
|-----------------|----------------------------------------|-------------------------------------|
| Storage         | `kubernetes/storage/`                  | NFS PV and PVC                      |
| Monitoring      | `kubernetes/monitoring/`               | Prometheus + Grafana                |
| Nginx           | `kubernetes/nginx/`                    | Sample app (2 replicas)             |
| Security        | `kubernetes/security/`                 | Network policies + RBAC             |
| Falco           | `kubernetes/falco/`                    | Runtime security (if enabled)       |

---

## ⚙️ Configuration Files

### Inventory (hosts.ini)
```ini
[masters]
k8s-master ansible_host=192.168.1.10

[workers]
k8s-worker1 ansible_host=192.168.1.11

[k8s_cluster:children]
masters
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
```

### Global Variables (all.yml) - Key 8GB Optimizations
```yaml
# CNI - Flannel for 8GB (uses ~50MB vs Calico's ~200MB)
cni_plugin: "flannel"

# Prometheus - Limited retention
prometheus_memory_limit: "512Mi"
prometheus_retention_time: "3d"
prometheus_retention_size: "1GB"

# Grafana - Reduced memory
grafana_memory_limit: "256Mi"

# Nginx - Reduced replicas
nginx_replicas: 2
nginx_memory_limit: "64Mi"

# Master can run workloads
allow_master_scheduling: true

# Falco - Optional for 8GB
enable_falco: true
falco_memory_limit: "256Mi"

# Kubelet resource reservations
kubelet_system_reserved_memory: "500Mi"
kubelet_system_reserved_cpu: "200m"
```

---

## 📊 8GB RAM Budget Breakdown

| **Component**          | **RAM Usage** | **Notes**                          |
|------------------------|---------------|-------------------------------------|
| Ubuntu OS (per node)   | 500 MB × 2    | Base OS overhead                   |
| Kubelet + Containerd   | 300 MB × 2    | Kubernetes node components         |
| etcd                   | 200 MB        | Master only                        |
| API Server + Controller| 400 MB        | Master only                        |
| Flannel CNI            | 50 MB × 2     | Lightweight networking             |
| Prometheus             | 512 MB        | With retention limits              |
| Grafana                | 256 MB        | Single instance                    |
| Nginx (2 pods)         | 64 MB         | Alpine image                       |
| Falco (optional)       | 256 MB        | Runtime security                   |
| **Reserved Buffer**    | 500 MB        | For spikes                         |
| **Total Used**         | ~4.5 GB       | Leaves headroom                    |

---

## 🔧 8GB-Specific Optimizations Applied

### 1. Flannel CNI (Instead of Calico)
- Uses ~50MB RAM vs Calico's ~200MB
- Configured in: `ansible/group_vars/all.yml`

### 2. Master Runs Workloads
- Removes `NoSchedule` taint to utilize master resources
- Set by: `allow_master_scheduling: true`

### 3. Resource-Limited Prometheus
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
args:
  - '--storage.tsdb.retention.time=3d'
  - '--storage.tsdb.retention.size=1GB'
```

### 4. Resource-Limited Grafana
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### 5. Nginx with Alpine Image
```yaml
image: nginx:alpine  # Smaller than nginx:latest
replicas: 2          # Reduced from 3
resources:
  requests:
    memory: "32Mi"
    cpu: "25m"
  limits:
    memory: "64Mi"
    cpu: "100m"
```

### 6. Kubelet System Reservations
```yaml
KUBELET_EXTRA_ARGS=--system-reserved=memory=500Mi,cpu=200m
```

---

## � CIS Kubernetes Benchmark Implementation

> The CIS (Center for Internet Security) Kubernetes Benchmark provides security guidelines for Kubernetes clusters. This project implements key CIS controls automatically via the `security` Ansible role.

### CIS Controls Implemented

| **CIS Control** | **Description**                                    | **Implementation**                                      |
|-----------------|----------------------------------------------------|---------------------------------------------------------|
| **1.1.1-1.1.11**| Control plane config file permissions              | API server, scheduler, controller manifests set to 0600 |
| **1.1.12**      | etcd data directory permissions                    | `/var/lib/etcd` set to 0700                             |
| **1.1.19-1.1.21**| PKI directory and certificate permissions         | Certs: 0644, Keys: 0600                                 |
| **4.1.1**       | Kubelet service file permissions                   | `10-kubeadm.conf` set to 0600                           |
| **4.1.5**       | Kubelet config file permissions                    | `config.yaml` set to 0600                               |
| **4.2.1**       | Anonymous authentication disabled                  | `anonymous.enabled: false` in kubelet config            |
| **4.2.4**       | Read-only port disabled                            | `readOnlyPort: 0` in kubelet config                     |
| **4.2.6**       | Protect kernel defaults                            | `protectKernelDefaults: true`                           |
| **5.1.5**       | Default service account not used                   | Enforced via Pod Security Standards                     |
| **5.2.2-5.2.9** | Pod Security Standards                             | PSS labels applied to namespaces                        |
| **5.3.2**       | Network Policies                                   | Default deny + explicit allow policies                  |

### Files Updated for CIS Compliance

| **File**                                      | **CIS Controls**                       |
|-----------------------------------------------|----------------------------------------|
| `ansible/roles/security/tasks/main.yml`       | 1.1.x, 4.1.x, 4.2.x, kernel hardening  |
| `kubernetes/security/pss-rbac.yaml`           | 5.2.x (Pod Security Standards)         |
| `kubernetes/security/network-policy.yaml`     | 5.3.2 (Network Policies)               |
| `ansible/roles/k8s_master/tasks/main.yml`     | 5.2.x (PSS namespace labels)           |

### CIS Verification Commands

```bash
# Check API server manifest permissions (CIS 1.1.1)
stat -c %a /etc/kubernetes/manifests/kube-apiserver.yaml
# Expected: 600

# Check etcd data directory permissions (CIS 1.1.12)
stat -c %a /var/lib/etcd
# Expected: 700

# Check kubelet anonymous auth disabled (CIS 4.2.1)
grep -A1 'anonymous:' /var/lib/kubelet/config.yaml
# Expected: enabled: false

# Check read-only port disabled (CIS 4.2.4)
grep 'readOnlyPort' /var/lib/kubelet/config.yaml
# Expected: readOnlyPort: 0

# Check PSS labels on namespace (CIS 5.2)
kubectl get namespace default --show-labels | grep pod-security
# Expected: pod-security.kubernetes.io/enforce=baseline

# Check network policies exist (CIS 5.3.2)
kubectl get networkpolicies -A
# Expected: default-deny-ingress, allow-nginx-ingress
```

### Security Hardening Summary

| **Category**              | **Controls Applied**                                    |
|---------------------------|--------------------------------------------------------|
| **Firewall (UFW)**        | Default deny incoming, allow specific K8s ports        |
| **SSH Hardening**         | Root login disabled, password auth disabled            |
| **Kernel Parameters**     | ASLR, rp_filter, ICMP protection, source routing       |
| **Control Plane Files**   | Manifests and PKI secured with proper permissions      |
| **Kubelet Hardening**     | Anonymous auth off, read-only port off                 |
| **Pod Security**          | PSS baseline enforcement on namespaces                 |
| **Network Policies**      | Default deny with explicit allow rules                 |

---

## �🖥️ Quick Start Guide

### Prerequisites
1. **2 Ubuntu 22.04 VMs** with 4GB RAM each
2. **SSH access** with key-based authentication
3. **Static IPs** configured on both VMs
4. **Ansible installed** on your control machine

### Step 1: Update Inventory
Edit `ansible/inventory/hosts.ini` with your VM IPs:
```ini
k8s-master ansible_host=YOUR_MASTER_IP
k8s-worker1 ansible_host=YOUR_WORKER_IP
```

### Step 2: Update Variables
Edit `ansible/group_vars/all.yml`:
```yaml
api_server_advertise_address: "YOUR_MASTER_IP"
nfs_server: "YOUR_NFS_SERVER"  # Optional
```

### Step 3: Run Deployment
```bash
cd ansible/
ansible-playbook -i inventory/hosts.ini site.yml
```

### Step 4: Verify Cluster
```bash
# SSH to master node
ssh ubuntu@YOUR_MASTER_IP

# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods --all-namespaces
```

---

## 🖥️ Service Access

| **Service**    | **Access URL**               | **Port** | **Credentials**     |
|----------------|------------------------------|----------|---------------------|
| Kubernetes API | https://<master-ip>:6443     | 6443     | kubeconfig token    |
| Prometheus     | http://<node-ip>:30090       | 30090    | N/A                 |
| Grafana        | http://<node-ip>:30300       | 30300    | admin / admin       |
| Nginx          | http://<node-ip>:30080       | 30080    | N/A                 |

---

## 🧪 Self-Healing Demonstration

### Test Pod Recreation
```bash
# List nginx pods
kubectl get pods -l app=nginx

# Delete a pod
kubectl delete pod <nginx-pod-name>

# Watch automatic recreation
kubectl get pods -l app=nginx -w
```

### Expected Result
Kubernetes automatically creates a new pod to maintain 2 replicas.

---

## 📝 Verification Checklist

### Cluster Health
- [ ] Both nodes in Ready state: `kubectl get nodes`
- [ ] All system pods running: `kubectl get pods -n kube-system`
- [ ] Flannel pods running: `kubectl get pods -n kube-flannel`

### Monitoring
- [ ] Prometheus accessible: `http://<node-ip>:30090`
- [ ] Grafana accessible: `http://<node-ip>:30300`

### Application
- [ ] Nginx deployment running: `kubectl get pods -l app=nginx`
- [ ] Service accessible: `curl http://<node-ip>:30080`

### Security (CIS Benchmarks)
- [ ] Network policies applied: `kubectl get networkpolicies -A`
- [ ] PSS labels on namespace: `kubectl get ns default --show-labels | grep pod-security`
- [ ] API server manifest permissions: `stat -c %a /etc/kubernetes/manifests/kube-apiserver.yaml` (expect 600)
- [ ] Kubelet anonymous auth disabled: `grep -A1 'anonymous:' /var/lib/kubelet/config.yaml`
- [ ] UFW firewall active: `sudo ufw status`

---

## 🔧 Troubleshooting

| **Issue**                | **Diagnostic Command**                    | **Resolution**                         |
|--------------------------|-------------------------------------------|----------------------------------------|
| Node NotReady            | `kubectl describe node <name>`            | Check kubelet logs, network            |
| Pod OOMKilled            | `kubectl describe pod <name>`             | Reduce workload or increase limits     |
| Flannel not starting     | `kubectl logs -n kube-flannel <pod>`      | Check IP pool configuration            |
| Prometheus high memory   | `kubectl top pod -n monitoring`           | Reduce retention time/size             |

---

## ⚠️ Features NOT Recommended for 8GB Setup

| **Feature**           | **RAM Impact** | **Recommendation**                                |
|-----------------------|----------------|---------------------------------------------------|
| Calico CNI            | ~200MB         | Use Flannel instead (~50MB)                       |
| TrueNAS NFS VM        | 2GB+           | Use external NFS server or local storage          |
| 3+ Worker Nodes       | 4GB each       | Stick to 2-node setup                             |
| 3+ Nginx Replicas     | ~32MB each     | Use 2 replicas maximum                            |

---

## 📚 References

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Flannel CNI Documentation](https://github.com/flannel-io/flannel)
- [Ansible Documentation](https://docs.ansible.com/)
- [Prometheus Documentation](https://prometheus.io/docs/)

---

## 👤 Project Information

| **Attribute**     | **Value**                                                    |
|-------------------|--------------------------------------------------------------|
| **Project Title** | Kubernetes Cluster Setup - 8GB Configuration                 |
| **Platform**      | DevOps                                                        |
| **Institution**   | CDAC                                                          |

---

*Document Version: 2.0 | Last Updated: February 2026*

# 📘 Kubernetes Cluster Automation — Complete Project Documentation

> **CDAC Project** — A production-grade, fully automated Kubernetes cluster with monitoring, security hardening, and persistent storage, built on Ubuntu 22.04 and orchestrated end-to-end with Ansible.

---

## 📑 Table of Contents

| # | Section | Description |
|---|---------|-------------|
| 1 | [What Is This Project?](#1-what-is-this-project) | High-level goal and the problem it solves |
| 2 | [Infrastructure Layout](#2-infrastructure-layout) | Nodes, IPs, and how they connect |
| 3 | [Technology Stack — What & Why](#3-technology-stack--what--why) | Every tool and the reason it was chosen |
| 4 | [Ansible Automation — Deep Dive](#4-ansible-automation--deep-dive) | Roles, plays, and execution flow |
| 5 | [Kubernetes Manifests — Deep Dive](#5-kubernetes-manifests--deep-dive) | Every manifest file explained |
| 6 | [Monitoring Stack](#6-monitoring-stack) | Prometheus, Grafana, Node Exporter, KSM |
| 7 | [Security Implementation](#7-security-implementation) | All 4 security layers explained |
| 8 | [Storage Architecture](#8-storage-architecture) | NFS, PVs, PVCs, and StorageClass |
| 9 | [Operational Scripts](#9-operational-scripts) | etcd backup & diagnostic scripts |
| 10 | [All Commands Used & Why](#10-all-commands-used--why) | Complete command reference |
| 11 | [Key Configuration Variables](#11-key-configuration-variables) | `all.yml` explained variable by variable |
| 12 | [Challenges & Lessons Learned](#12-challenges--lessons-learned) | Real issues faced and how they were solved |

---

## 1. What Is This Project?

### The Problem

Setting up a Kubernetes cluster manually is:
- ⏱️ **Time-consuming** — 2–3 hours of repetitive terminal commands per node.
- ❌ **Error-prone** — One wrong `sysctl` value and networking breaks silently.
- 🔀 **Inconsistent** — Two engineers will produce two different clusters.
- 🔓 **Insecure by default** — Vanilla K8s has no firewall rules, no pod restrictions, no monitoring.

### The Solution

This project converts the entire process into a **single Ansible command**:

```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

This one command does all of the following automatically:
1. Prepares the OS (disables swap, loads kernel modules, installs packages)
2. Installs and configures `containerd` as the container runtime
3. Installs Kubernetes v1.29 (`kubelet`, `kubeadm`, `kubectl`)
4. Hardens the host (UFW firewall, SSH lockdown, CIS benchmarks)
5. Initializes the control plane with `kubeadm init`
6. Installs Flannel CNI for pod networking
7. Joins worker nodes to the cluster
8. Deploys a full monitoring stack (Prometheus + Grafana + Node Exporter + Kube-State-Metrics)
9. Deploys an Nginx sample workload with self-healing probes
10. Applies Network Policies and RBAC security
11. Optionally deploys Falco for runtime threat detection
12. Sets up automated hourly etcd backups

---

## 2. Infrastructure Layout

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        NETWORK: 192.168.144.0/24                        │
│                                                                          │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │  MASTER NODE         │  │  WORKER NODE         │  │  NFS SERVER     │  │
│  │  192.168.144.130     │  │  192.168.144.134     │  │  192.168.144.132│  │
│  │                      │  │                      │  │                 │  │
│  │  • kube-apiserver    │  │  • kubelet            │  │  /srv/nfs/      │  │
│  │  • etcd              │  │  • kube-proxy         │  │   kubernetes/   │  │
│  │  • kube-scheduler    │  │  • containerd         │  │   ├─prometheus/ │  │
│  │  • controller-mgr    │  │  • Flannel agent      │  │   ├─grafana/    │  │
│  │  • kubelet           │  │                      │  │   ├─nginx/      │  │
│  │  • containerd        │  │  Runs:               │  │   etcd-backups/ │  │
│  │  • Flannel agent     │  │  • Nginx pods         │  │                 │  │
│  │                      │  │  • Node Exporter      │  │                 │  │
│  │  Runs:               │  │  • Falco (optional)   │  │                 │  │
│  │  • Prometheus        │  │                      │  │                 │  │
│  │  • Grafana           │  └──────────┬───────────┘  └────────┬────────┘  │
│  │  • KSM               │             │                       │           │
│  │  • Node Exporter     │             │                       │           │
│  │  • Falco (optional)  │             │                       │           │
│  └──────────┬───────────┘             │                       │           │
│             │         ┌───────────────┘                       │           │
│             │         │        NFS Mount (/mnt/nfs)           │           │
│             └─────────┴───────────────────────────────────────┘           │
│                    Flannel VXLAN Overlay (10.244.0.0/16)                  │
└──────────────────────────────────────────────────────────────────────────┘
```

### Why 2 Nodes + NFS?

| Design Decision | Reasoning |
|---|---|
| **2 nodes** | Optimized for 8GB total RAM. Master runs workloads too (taint removed). |
| **Separate NFS server** | Data survives node restarts/crashes. Decouples storage from compute. |
| **Master scheduling enabled** | With only 2 nodes, we can't "waste" the master on control plane duties only. |

---

## 3. Technology Stack — What & Why

### A. Ansible — Infrastructure as Code

| Aspect | Detail |
|---|---|
| **What** | Agentless configuration management tool that uses SSH and YAML playbooks. |
| **Why not Terraform?** | Terraform provisions infrastructure (VMs, cloud). Ansible *configures* existing servers. Since our VMs already exist, Ansible is the right choice. |
| **Why not Chef/Puppet?** | Both require agents installed on target machines. Ansible is agentless — it logs in via SSH and runs commands. Simpler setup, zero overhead. |
| **Key Feature Used** | **Idempotency** — Running the playbook twice produces the same result without breaking anything. |

### B. containerd — Container Runtime

| Aspect | Detail |
|---|---|
| **What** | A lightweight container runtime that manages the complete container lifecycle. |
| **Why not Docker?** | Kubernetes 1.24+ **removed Docker (dockershim) support**. `containerd` is the official recommended CRI runtime. |
| **Memory benefit** | Uses ~50MB vs Docker's ~100MB. In our 8GB environment, this matters. |
| **Configuration done** | Set `SystemdCgroup = true` in `/etc/containerd/config.toml` to match kubelet's cgroup driver. |

### C. Flannel CNI — Pod Networking

| Aspect | Detail |
|---|---|
| **What** | A simple overlay network using VXLAN that assigns a `/24` subnet to each node from the `10.244.0.0/16` pool. |
| **Why not Calico?** | Calico uses ~100–150MB per node and brings BGP routing complexity. Flannel uses ~50MB. |
| **Trade-off** | Flannel doesn't support Network Policies natively, so we implement them separately via Kubernetes `NetworkPolicy` resources. |

### D. Prometheus + Grafana — Monitoring

| Component | What It Does | Why Needed |
|---|---|---|
| **Prometheus** | Scrapes `/metrics` endpoints every 30s, stores as time-series data | Without it, you're blind to CPU spikes, memory leaks, pod crashes |
| **Grafana** | Visualizes Prometheus data as dashboards with graphs and alerts | Numbers in a terminal don't help. Visual dashboards enable fast decisions. |
| **Node Exporter** | Exposes OS/hardware metrics (CPU, RAM, disk) on port 9100 | Kubernetes doesn't expose host-level metrics. Node Exporter fills that gap. |
| **Kube-State-Metrics** | Exposes Kubernetes object state (pod count, deployment health) on port 8080 | Without it, Grafana can't show how many pods are running or crashing. |

### E. NFS — Persistent Storage

| Aspect | Detail |
|---|---|
| **What** | Network File System — allows pods on different nodes to read/write to the same shared directory. |
| **Why not hostPath?** | `hostPath` ties data to a single node. If that node dies, data is lost. |
| **Why not Ceph/Longhorn?** | Both require 500MB+ per node. Way too heavy for 8GB RAM. |
| **Key Feature** | Supports `ReadWriteMany (RWX)` access mode — multiple pods write simultaneously. |

### F. Falco — Runtime Security

| Aspect | Detail |
|---|---|
| **What** | A runtime security engine that monitors Linux system calls (syscalls) to detect threats in real-time. |
| **Why** | Firewalls protect the perimeter. RBAC controls API access. But if an attacker gets into a container, Falco detects it immediately. |
| **How** | Uses eBPF/kernel module to intercept system calls. Matches against rules (e.g., "bash spawned in a container"). |

---

## 4. Ansible Automation — Deep Dive

### Project Structure

```
ansible/
├── inventory/
│   └── hosts.ini              # Target server IPs and SSH config
├── group_vars/
│   └── all.yml                # Global variables (versions, IPs, resource limits)
├── site.yml                   # Main playbook — orchestrates 4 plays
└── roles/
    ├── common/                # Play 1: OS preparation (ALL nodes)
    │   ├── tasks/main.yml     # 13 tasks: swap, modules, containerd, K8s packages
    │   └── handlers/main.yml  # Restart handlers for containerd, kubelet
    ├── security/              # Play 1: Host hardening (ALL nodes)
    │   ├── tasks/main.yml     # UFW firewall, SSH hardening, CIS benchmarks
    │   └── handlers/main.yml  # Restart handlers for SSH, kubelet
    ├── k8s_master/            # Play 2: Control plane (MASTER only)
    │   ├── tasks/main.yml     # kubeadm init, CNI, PSS, etcd backup
    │   └── handlers/main.yml  # Service restart handlers
    └── k8s_worker/            # Play 3: Cluster join (WORKERS only)
        └── tasks/main.yml     # kubeadm join, readiness check
```

### The 4 Plays in `site.yml`

#### Play 1 — All Nodes: `common` + `security` roles

**Purpose**: Prepare every node to be a valid Kubernetes member.

| # | Task | Why It's Needed |
|---|---|---|
| 1 | `swapoff -a` | Kubernetes scheduler can't manage memory with swap ON. | 
| 2 | Comment swap in `/etc/fstab` | Makes swap disablement persist across reboots. |
| 3 | Install `apt-transport-https`, `curl`, `nfs-common` | Prerequisites for adding K8s repository and mounting NFS. |
| 4 | `modprobe overlay` | Enables overlay filesystem — required by containerd. |
| 5 | `modprobe br_netfilter` | Lets bridges pass traffic to iptables — required for Flannel. |
| 6 | sysctl: `net.ipv4.ip_forward=1` | Enables packet forwarding between pod subnets. |
| 7 | sysctl: `bridge-nf-call-iptables=1` | Ensures bridged traffic is processed by iptables rules. |
| 8 | Install `containerd` | Container runtime. |
| 9 | Set `SystemdCgroup=true` | Kubelet and containerd must use the same cgroup driver. |
| 10 | Add K8s APT repo and install `kubelet`, `kubeadm`, `kubectl` v1.29 | Core Kubernetes binaries. |
| 11 | `dpkg --set-selections hold` | Prevents `apt upgrade` from accidentally upgrading K8s versions. |
| 12 | Configure kubelet resource reservations | Reserves 500Mi memory and 200m CPU for the OS itself. |
| 13 | Update `/etc/hosts` | So nodes can resolve each other by hostname, not just IP. |

Then the `security` role runs (detailed in [Section 7](#7-security-implementation)).

#### Play 2 — Master Only: `k8s_master` role

| # | Task | Why |
|---|---|---|
| 1 | Check if already initialized | Makes the playbook idempotent (safe to re-run). |
| 2 | `kubeadm init` | Creates PKI certs, starts etcd, API server, scheduler, controller-manager. |
| 3 | Copy `admin.conf` to `~root/.kube/config` | So `kubectl` works for the root user. |
| 4 | Copy `admin.conf` to `~ubuntu/.kube/config` | So `kubectl` works for the normal user too. |
| 5 | Install Flannel CNI | Creates the pod overlay network (10.244.0.0/16). |
| 6 | Remove `NoSchedule` taint | Allows pods to run on the master (needed for 2-node setup). |
| 7 | `kubeadm token create --print-join-command` | Generates the `kubeadm join` command for workers. |
| 8 | Apply Pod Security Standards | Labels the `default` namespace with `enforce=baseline`. |
| 9 | Set up etcd backup cron | Installs hourly `etcdctl snapshot save` via crontab. |

#### Play 3 — Workers Only: `k8s_worker` role

| # | Task | Why |
|---|---|---|
| 1 | Check if already joined | Makes the playbook idempotent. |
| 2 | Get join command from master | Uses Ansible's `hostvars` to read the saved join command. |
| 3 | `kubeadm join` | Registers the worker with the API server using a bootstrap token. |
| 4 | Wait for node to be `Ready` | Polls `kubectl get node` until the CNI is initialized. |

#### Play 4 — Deploy Cluster Services

| # | Task | Why |
|---|---|---|
| 1 | Wait for all nodes to be Ready | Ensures the cluster is stable before deploying workloads. |
| 2 | Copy `kubernetes/` manifests to `/opt/kubernetes/` | Transfers all YAML files to the master node. |
| 3 | `kubectl apply -f storage/` | Creates StorageClass, PersistentVolumes, PVCs. |
| 4 | `kubectl apply -f monitoring/` | Deploys Prometheus, Grafana, Node Exporter, KSM. |
| 5 | `kubectl apply -f nginx/` | Deploys the sample Nginx workload. |
| 6 | `kubectl apply -f security/` | Applies Network Policies and RBAC. |
| 7 | `kubectl apply -f falco/` (if enabled) | Deploys Falco runtime security DaemonSet. |

---

## 5. Kubernetes Manifests — Deep Dive

### File-by-File Breakdown

| Directory | File | What It Creates | Why |
|---|---|---|---|
| `storage/` | `storage-class.yaml` | `nfs-storage` StorageClass | Groups all NFS PVs under one provisioner so PVCs can request storage dynamically. |
| `storage/` | `nfs-pv.yaml` | 4 PersistentVolumes (10Gi, 5Gi, 2Gi, 1Gi) | Pre-allocates NFS-backed storage for each service. |
| `storage/` | `nfs-pvc.yaml` | 4 PersistentVolumeClaims | Pods claim storage via PVC names, not direct NFS paths. |
| `monitoring/` | `namespace.yaml` | `monitoring` namespace | Isolates monitoring workloads from the default namespace. |
| `monitoring/` | `prometheus.yaml` | ServiceAccount, ClusterRole, ClusterRoleBinding, ConfigMap, Deployment, Service | Prometheus needs RBAC to query the K8s API for service discovery. |
| `monitoring/` | `prometheus-alerts.yaml` | AlertManager rules ConfigMap | Defines when to fire alerts (CPU > 80%, Node Down, etc.). |
| `monitoring/` | `grafana.yaml` | Datasource ConfigMap, Deployment (with health probes), Service | Auto-connects to Prometheus on startup; no manual config needed. |
| `monitoring/` | `grafana-dashboards.yaml` | Dashboard JSON ConfigMaps | Pre-loaded dashboards for instant visibility. |
| `monitoring/` | `kube-state-metrics.yaml` | RBAC, Deployment, Service | Translates K8s API objects into Prometheus metrics. |
| `monitoring/` | `node-exporter.yaml` | DaemonSet (hostNetwork, hostPID), Service | Runs on every node, exposes OS metrics on port 9100. |
| `nginx/` | `deployment.yaml` | Deployment (2 replicas, liveness/readiness probes), Service (NodePort 30080) | Sample workload demonstrating PSS compliance and self-healing. |
| `security/` | `network-policy.yaml` | 3 NetworkPolicies (default-deny, allow-nginx, allow-prometheus-scrape) | Implements zero-trust networking. |
| `security/` | `pss-rbac.yaml` | PSS labels, RBAC Role, RoleBinding | Grants a `developer` user read-only access to pods. |
| `falco/` | `falco.yaml` | Namespace, ServiceAccount, RBAC, ConfigMap (with custom rules), DaemonSet, Service | Runtime threat detection with 3 custom rules. |

---

## 6. Monitoring Stack

### How Metrics Flow

```
Node Exporter (:9100)  ──┐
KSM (:8080)             ──┤
K8s API (/metrics)       ──┼──→  Prometheus (:9090 → NodePort :30090)  ──→  Grafana (:3000 → NodePort :30300)
Kubelet (/metrics)       ──┤                  │
Falco (:8765)            ──┘          Alert Rules fire
                                    on thresholds
```

### Scrape Configuration

| Job Name | Target | Metrics Collected | Interval |
|---|---|---|---|
| `prometheus` | localhost:9090 | Self-monitoring | 30s |
| `kubernetes-apiservers` | K8s API endpoint | API server latency, request count | 30s |
| `kubernetes-nodes` | All kubelets via API proxy | Container CPU/memory via cAdvisor | 30s |
| `node-exporter` | All nodes on :9100 | Host CPU, RAM, disk, network | 30s |
| `kube-state-metrics` | kube-state-metrics:8080 | Pod count, deployment status, node health | 30s |
| `falco` | Falco pods on :8765 | Security event counts | 30s |

### Alert Rules Defined

| Alert Name | Fires When | Severity |
|---|---|---|
| `NodeDown` | Node unreachable for 2 mins | 🔴 Critical |
| `HighCPUUsage` | CPU > 80% for 5 mins | 🟡 Warning |
| `HighMemoryUsage` | RAM > 85% for 5 mins | 🟡 Warning |
| `DiskSpaceLow` | Disk < 15% free | 🟡 Warning |
| `PodCrashLooping` | Restarts > 0.5/min for 5 mins | 🟡 Warning |
| `DeploymentReplicasMismatch` | Actual ≠ Desired replicas for 10 mins | 🟡 Warning |

### Pre-Built Grafana Dashboards

| Dashboard | What It Shows |
|---|---|
| Cluster Overview | Total pods, node count, namespace breakdown |
| Node Metrics | Per-node CPU, memory, disk, network bandwidth |
| Pod Resources | Per-pod resource usage vs. limits |
| Falco Security | Runtime security event timeline |

---

## 7. Security Implementation

### The 4 Security Layers

```
                    ┌─────────────────────────────────────────────┐
                    │        Layer 4: RUNTIME SECURITY            │
                    │        Falco — syscall monitoring           │
                    │        (detects shell-in-container,         │
                    │         sensitive file reads, kubectl exec) │
                    ├─────────────────────────────────────────────┤
                    │        Layer 3: NETWORK SECURITY            │
                    │        NetworkPolicies — zero-trust          │
                    │        (default deny all, whitelist nginx    │
                    │         and Prometheus scrape only)          │
                    ├─────────────────────────────────────────────┤
                    │        Layer 2: KUBERNETES SECURITY          │
                    │        PSS — enforce baseline                │
                    │        RBAC — pod-reader role                │
                    │        ServiceAccount restrictions           │
                    ├─────────────────────────────────────────────┤
                    │        Layer 1: HOST SECURITY                │
                    │        UFW Firewall, SSH Hardening,          │
                    │        CIS Kubernetes Benchmarks,            │
                    │        Kernel Hardening (ASLR, rp_filter)   │
                    └─────────────────────────────────────────────┘
```

### Layer 1: Host Security (Ansible `security` role)

**UFW Firewall Rules:**

| Port | Protocol | Service | Scope |
|---|---|---|---|
| 22 | TCP | SSH | All nodes |
| 6443 | TCP | K8s API Server | Master only |
| 2379-2380 | TCP | etcd | Master only |
| 10250 | TCP | Kubelet API | All nodes |
| 10251 | TCP | kube-scheduler | Master only |
| 10252 | TCP | controller-manager | Master only |
| 30000-32767 | TCP | NodePort range | All nodes |
| 8472 | UDP | Flannel VXLAN | All nodes |
| 9100 | TCP | Node Exporter | All nodes |

**SSH Hardening:**
- `PermitRootLogin no` — Blocks direct root SSH access.
- `PasswordAuthentication no` — Forces SSH key-based authentication.

**Kernel Hardening:**

| Parameter | Value | Why |
|---|---|---|
| `kernel.randomize_va_space` | `2` | Full ASLR — makes memory exploits harder. |
| `net.ipv4.conf.all.rp_filter` | `1` | Reverse path filtering — blocks IP spoofing. |
| `net.ipv4.conf.all.accept_source_route` | `0` | Blocks source-routed packets. |
| `net.ipv4.icmp_echo_ignore_broadcasts` | `1` | Prevents Smurf DDoS attacks. |

**CIS Kubernetes Benchmark Controls:**

| CIS Control | What Is Done |
|---|---|
| CIS 1.1.1-1.1.21 | Set file permissions to `0600` on API server, scheduler, controller-manager, and etcd manifests. |
| CIS 1.1.12 | Secure etcd data directory with `0700` permissions. |
| CIS 1.1.19-21 | Secure PKI certificates (`.crt` = 0644, `.key` = 0600). |
| CIS 4.1.1 | Secure kubelet service file with `0600` permissions. |
| CIS 4.2.1 | Disable anonymous kubelet authentication. |
| CIS 4.2.4 | Disable kubelet read-only port (`readOnlyPort: 0`). |

### Layer 2: Kubernetes Security

**Pod Security Standards (PSS):**

| Level | Applied As | Effect |
|---|---|---|
| `baseline` | `enforce` | Blocks privileged containers, hostNetwork, hostPath, dangerous capabilities |
| `baseline` | `warn` | Shows a warning in CLI for violations |
| `baseline` | `audit` | Logs violations in the audit log |

**RBAC:**
- A `pod-reader` ClusterRole is created with `get`, `list`, `watch` permissions on pods.
- Bound to a `developer` user via `RoleBinding`.

### Layer 3: Network Policies

| Policy Name | Effect |
|---|---|
| `default-deny-ingress` | Blocks ALL incoming traffic to the `default` namespace. |
| `allow-nginx-ingress` | Opens port 8080 on pods with `app: nginx` label. |
| `allow-prometheus-scrape` | Allows the `monitoring` namespace to scrape port 8080 in `default` namespace. |

### Layer 4: Falco Runtime Security

**Custom Detection Rules:**

| Rule | Priority | What It Catches |
|---|---|---|
| **Shell Spawned in Container** | ⚠️ WARNING | Any `bash`, `sh`, or `zsh` executed inside a container. |
| **Sensitive File Access** | 🔴 CRITICAL | Reading `/etc/shadow`, `/etc/passwd`, or `/etc/kubernetes/admin.conf`. |
| **Kubectl Exec Detected** | 📝 NOTICE | Any `kubectl exec` into a pod. |

---

## 8. Storage Architecture

### The NFS Model

```
NFS Server (192.168.144.132)
│
├── /srv/nfs/kubernetes           → PV: nfs-kubernetes-pv (10Gi)  → PVC: nfs-pvc
├── /srv/nfs/kubernetes/prometheus → PV: nfs-prometheus-pv (5Gi)  → PVC: prometheus-pvc
├── /srv/nfs/kubernetes/grafana   → PV: nfs-grafana-pv (2Gi)     → PVC: grafana-pvc
├── /srv/nfs/kubernetes/nginx     → PV: nfs-nginx-pv (1Gi)       → PVC: nginx-pvc
└── /srv/nfs/etcd-backups         → Mounted at /mnt/nfs/etcd-backups (via cron script)
```

### Key Design Choices

| Choice | Why |
|---|---|
| `ReclaimPolicy: Retain` | Data is preserved even if PVC is deleted. Important for Prometheus metrics. |
| `AccessMode: ReadWriteMany` | Multiple pods on different nodes can mount the same volume simultaneously. |
| `StorageClass: nfs-storage` | Groups all NFS PVs under one class so PVCs can find them. |
| `WaitForFirstConsumer` binding mode | PV binds only when a pod actually needs it, improving scheduling flexibility. |

---

## 9. Operational Scripts

### `etcd-backup.sh` — Automated Cluster State Backup

**What it does:**
1. Takes an `etcdctl snapshot` using TLS certificates.
2. Verifies the snapshot integrity with `etcdctl snapshot status`.
3. Copies the snapshot to the NFS server for off-node backup.
4. Cleans up old snapshots (local: keep 24h, NFS: keep 7 days).

**Scheduled via**: `cron` — Runs every hour at minute 0 (`0 * * * *`).

**Key command inside:**
```bash
etcdctl snapshot save /backup/etcd/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### `diagnose-services.sh` — 14-Point Health Check

Performs these checks in order:

| # | Check | Command Used |
|---|---|---|
| 1 | Cluster connectivity | `kubectl cluster-info` |
| 2 | Node status | `kubectl get nodes -o wide` |
| 3 | Namespaces exist | `kubectl get namespaces` |
| 4 | PV status | `kubectl get pv -o wide` |
| 5 | PVC binding | `kubectl get pvc --all-namespaces` |
| 6 | Pending PVCs | Filters for PVCs not in `Bound` state |
| 7 | Deployment status | `kubectl get deployments -l 'app in (prometheus,grafana,nginx)'` |
| 8 | Pod health | `kubectl get pods` filtered for service pods |
| 9 | Problem pods | Filters for non-Running pods with `kubectl describe` |
| 10 | Service status | `kubectl get svc` |
| 11 | NodePort access URLs | Prints Prometheus/Grafana/Nginx URLs |
| 12 | Firewall status | `ufw status` |
| 13 | Service endpoints | `kubectl get endpoints` per service |
| 14 | NFS connectivity | `ping` + `showmount -e` to NFS server |

---

## 10. All Commands Used & Why

### Ansible Commands

| Command | Purpose |
|---|---|
| `ansible-playbook -i inventory/hosts.ini site.yml` | Full cluster deployment — the "one command" |
| `ansible-playbook site.yml --tags common` | Run only the `common` role (for debugging) |
| `ansible-playbook site.yml --check` | Dry run — shows what WOULD change without doing it |
| `ansible-playbook site.yml -vvv` | Maximum verbosity — debugging SSH or module failures |

### kubeadm Commands

| Command | Purpose |
|---|---|
| `kubeadm init --apiserver-advertise-address=... --pod-network-cidr=10.244.0.0/16` | Initializes the control plane; `pod-network-cidr` must match Flannel's expected range |
| `kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>` | Worker joins the cluster; token validates identity, hash validates the master's certificate |
| `kubeadm token create --print-join-command` | Regenerates a new join command (tokens expire after 24h) |
| `kubeadm reset -f` | Completely tears down K8s on a node — useful for clean re-initialization |

### kubectl Commands

| Command | Purpose |
|---|---|
| `kubectl get nodes -o wide` | Shows node IPs, OS, kernel, and container runtime versions |
| `kubectl get pods -A` | Lists all pods across all namespaces — the "is everything working?" check |
| `kubectl describe pod <name>` | Shows events, conditions, mount failures, scheduling decisions |
| `kubectl logs <pod>` | Reads container stdout/stderr — critical for debugging crashes |
| `kubectl apply -f <file.yaml>` | Creates or updates Kubernetes resources declaratively |
| `kubectl delete pod <name>` | Tests self-healing — Deployment controller recreates it |
| `kubectl exec -it <pod> -- /bin/sh` | Drops into a container shell for debugging (Falco detects this!) |
| `kubectl scale deployment nginx --replicas=5` | Horizontally scales the Nginx deployment |
| `kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-` | Removes the default taint, allowing pods on master |
| `kubectl label namespace default pod-security.kubernetes.io/enforce=baseline` | Applies Pod Security Standards at the namespace level |

### System/OS Commands

| Command | Purpose | Used In |
|---|---|---|
| `swapoff -a` | Disables swap at runtime | `common` role |
| `modprobe overlay` | Loads overlay filesystem kernel module | `common` role |
| `modprobe br_netfilter` | Enables bridge network filtering | `common` role |
| `sysctl -w net.ipv4.ip_forward=1` | Allows pods to communicate across nodes | `common` role |
| `ufw enable` | Activates the firewall with configured rules | `security` role |
| `systemctl restart kubelet` | Applies kubelet configuration changes | Handlers |
| `etcdctl snapshot save` | Creates a backup of the entire cluster state | `etcd-backup.sh` |

---

## 11. Key Configuration Variables

All configurable values are in `ansible/group_vars/all.yml`:

| Variable | Value | Why This Value |
|---|---|---|
| `kubernetes_version` | `1.29` | Latest stable release at project creation time |
| `pod_network_cidr` | `10.244.0.0/16` | Required match for Flannel's default configuration |
| `service_cidr` | `10.96.0.0/12` | Kubernetes default; provides 1M+ service IPs |
| `api_server_advertise_address` | `192.168.144.130` | Master node's IP; workers connect to this |
| `cni_plugin` | `flannel` | Lower memory than Calico; fine for 2-node labs |
| `nfs_server` | `192.168.144.132` | IP of the Ubuntu NFS server |
| `nfs_path` | `/srv/nfs/kubernetes` | Root NFS export directory |
| `prometheus_nodeport` | `30090` | Access Prometheus UI from browser |
| `prometheus_memory_limit` | `512Mi` | Capped for 8GB RAM environment |
| `grafana_nodeport` | `30300` | Access Grafana UI from browser |
| `grafana_admin_password` | `admin` | Default password (change in production!) |
| `nginx_replicas` | `2` | Reduced from default 3 to fit in 8GB RAM |
| `enable_firewall` | `true` | UFW is always enabled for security |
| `pss_level` | `baseline` | Blocks dangerous pod configurations |
| `enable_falco` | `true` | Runtime security monitoring enabled |
| `allow_master_scheduling` | `true` | Removes NoSchedule taint from master |
| `kubelet_system_reserved_memory` | `500Mi` | Reserves memory for Ubuntu OS processes |
| `kubelet_system_reserved_cpu` | `200m` | Reserves CPU for Ubuntu OS processes |

---

## 12. Challenges & Lessons Learned

### Challenge 1: `kubeadm init` Fails with "API server not responding"

| Aspect | Detail |
|---|---|
| **Root Cause** | Swap was disabled at runtime with `swapoff -a` but was still in `/etc/fstab`, so it came back after reboot. |
| **Fix** | Added a second Ansible task to comment out the swap line in `/etc/fstab`. |
| **Lesson** | Always handle both **runtime** AND **persistent** configuration. |

### Challenge 2: Flannel Pods Stuck in `Init:0/1`

| Aspect | Detail |
|---|---|
| **Root Cause** | The `br_netfilter` kernel module wasn't loaded before the sysctl parameter `bridge-nf-call-iptables` was set. |
| **Fix** | Reordered Ansible tasks: `modprobe br_netfilter` → THEN → `sysctl bridge-nf-call-iptables=1`. |
| **Lesson** | Order of operations matters. Dependencies must be resolved before dependents. |

### Challenge 3: PVCs Stuck in `Pending`

| Aspect | Detail |
|---|---|
| **Root Cause** | The PV's `storageClassName` didn't match the PVC's requested class. |
| **Fix** | Ensured both PV and PVC use `storageClassName: nfs-storage` consistently. |
| **Lesson** | Kubernetes PV-PVC binding is label/class-sensitive. Mismatches fail silently. |

### Challenge 4: Nginx Pods Rejected by PSS

| Aspect | Detail |
|---|---|
| **Root Cause** | PSS `baseline` enforcement blocked the standard `nginx` image because it runs as root. |
| **Fix** | Switched to `nginxinc/nginx-unprivileged:alpine` and added full `securityContext` (runAsNonRoot, drop ALL capabilities). |
| **Lesson** | Security and convenience are trade-offs. PSS compliance requires non-root images. |

---

> **End of Documentation** — This document covers every component, command, and design decision in the project.

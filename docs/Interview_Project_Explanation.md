# 🎤 Explain Your Project — Interview Ready Guide

> **When the interviewer says: "Tell me about your project"**
> Use this as your go-to reference. It covers what the project does, how it works, every command used, and the complete security implementation.

---

## 🗣️ The 2-Minute Pitch

> "I built a fully automated Kubernetes infrastructure that provisions in minutes using **Ansible**. The architecture consists of Master and Worker nodes connected to an NFS external storage server. For observability, I deployed **Grafana and Prometheus** along with **Node Exporter**, which pulls underlying OS metrics from files and feeds them to Grafana for dashboards. The cluster features **self-healing pods** and a strong security posture, notably using **Falco** to monitor pod behavior and detect runtime threats via syscalls. I've also implemented autoscaling for my Nginx web application — both **Horizontal Pod Autoscaler (HPA)** for handling traffic spikes and **Vertical Pod Autoscaler (VPA)** for right-sizing resources — while ensuring all web data remains entirely **persistent** across pod restarts."

---

## � Pitch Decoder: How to Answer Follow-up Questions

If the interviewer stops you and asks, *"Exactly how did you implement `[Buzzword]`?"*, here is your exact technical answer:

| You said... | The Interviewer asks... | Your Technical Answer |
|-------------|-------------------------|-----------------------|
| **"Ansible"** | *What Ansible command did you run?* | "I structured the project into roles (`common`, `k8s_master`, etc.) and ran a single command: `ansible-playbook -i inventory/hosts.ini site.yml`. It handles everything via SSH." |
| **"Master & Worker"** | *How did you join the worker?* | "My Ansible playbook runs `kubeadm init` on the master, captures the output token, and passes it to the worker using `kubeadm join <master-ip>:6443 --token <token>`." |
| **"Prometheus & Grafana"** | *How were they deployed?* | "Using native Kubernetes manifests. I applied them with `kubectl apply -f /opt/kubernetes/monitoring/`. I didn't use Helm because I wanted explicit control over the resource limits for my 8GB RAM constraint." |
| **"Node Exporter"** | *How does it get OS metrics?* | "It runs as a `DaemonSet` using `hostNetwork: true` and mounts the node's `/proc` and `/sys` directories to read kernel and hardware metrics." |
| **"Self-healing"** | *How exactly does it self-heal?* | "My Nginx deployment uses `livenessProbe` (HTTP GET on port 8080). If it fails 3 times, the kubelet restarts the container. If the entire pod dies, the `ReplicaSet` recreates it." |
| **"Falco via syscalls"** | *How does Falco intercept syscalls?* | "Falco runs as a privileged `DaemonSet`. It uses an **eBPF probe** attached to the Linux kernel to monitor system calls (like a shell spawning) without modifying the kernel itself." |
| **"HPA & VPA"** | *What metrics do they scale on?* | "They rely on the `metrics-server` pod. The HPA scales *horizontally* based on average CPU utilization hitting 70%. The VPA scales *vertically* by adjusting the container's CPU/RAM `requests` based on historical usage." |
| **"Persistent storage"** | *How is data persistent?* | "I set up an external NFS server. In Kubernetes, I created a `StorageClass`, a `PersistentVolume` (PV), and bound my Nginx pods to it using a `PersistentVolumeClaim` (PVC) mounted at `/usr/share/nginx/html`." |

---

## �📐 Project Architecture at a Glance

```
   ANSIBLE CONTROL MACHINE
         │
         │  $ ansible-playbook -i inventory/hosts.ini site.yml
         │
         ├──── SSH ──── MASTER NODE (192.168.144.130) ──── 4GB RAM
         │               ├── API Server :6443
         │               ├── etcd :2379
         │               ├── Scheduler
         │               └── Controller Manager
         │
         ├──── SSH ──── WORKER NODE (192.168.144.134) ──── 4GB RAM
         │               ├── kubelet
         │               ├── kube-proxy
         │               └── containerd
         │
         │                    ┌──────────────────────────────┐
         └──── kubectl ──────│     DEPLOYED SERVICES         │
                             │                               │
                             │  Prometheus    :30090          │
                             │  Grafana       :30300          │
                             │  Nginx (x2)    :30080          │
                             │  Node Exporter :9100           │
                             │  KSM           :8080           │
                             │  Falco         (DaemonSet)     │
                             │  Metrics Server                │
                             └──────────┬────────────────────┘
                                        │
                         ┌──────────────┴──────────────┐
                         │       AUTOSCALING           │
                         │   HPA: Scales Nginx replicas│
                         │   VPA: Tunes CPU/RAM limits │
                         └──────────────┬──────────────┘
                                        │
                                        │ PVC (NFS)
                                        ▼
                             NFS SERVER (192.168.144.132)
                             ├── /srv/nfs/kubernetes/prometheus  (5Gi)
                             ├── /srv/nfs/kubernetes/grafana     (2Gi)
                             ├── /srv/nfs/kubernetes/nginx       (1Gi)
                             └── /srv/nfs/etcd-backups           (7 days)
```

---

## 🔧 Step-by-Step: What Happens When I Run the Playbook

### Step 1 — Configure Target Servers

```bash
# Edit inventory with server IPs
nano ansible/inventory/hosts.ini
```
```ini
[masters]
k8s-master ansible_host=192.168.144.130

[workers]
k8s-worker1 ansible_host=192.168.144.134

[k8s_cluster:children]
masters
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

```bash
# Edit global variables
nano ansible/group_vars/all.yml
```
Key variables I configure:
| Variable | Value | Why |
|----------|-------|-----|
| `kubernetes_version` | `1.29` | Latest stable K8s |
| `cni_plugin` | `flannel` | Uses ~50MB vs Calico's ~200MB |
| `nfs_server` | `192.168.144.132` | External NFS for persistence |
| `pss_level` | `baseline` | Blocks privileged containers |
| `enable_falco` | `true` | Runtime threat detection |
| `allow_master_scheduling` | `true` | Use master as worker too (8GB RAM) |

---

### Step 2 — Run the Playbook (One Command)

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

This triggers **4 plays** in sequence:

---

### Play 1: OS Preparation + Security (ALL nodes)

**What it does**: Prepares Ubuntu servers for Kubernetes

| # | Command / Action | Purpose |
|---|------------------|---------|
| 1 | `swapoff -a` | Disable swap (K8s requirement) |
| 2 | Edit `/etc/fstab` | Disable swap permanently |
| 3 | `apt install apt-transport-https curl nfs-common` | Install dependencies |
| 4 | `modprobe overlay` | Load overlay kernel module for containers |
| 5 | `modprobe br_netfilter` | Load bridge netfilter for K8s networking |
| 6 | `sysctl net.bridge.bridge-nf-call-iptables=1` | Enable iptables for bridged traffic |
| 7 | `sysctl net.ipv4.ip_forward=1` | Enable IP forwarding for pod networking |
| 8 | `apt install containerd` | Install container runtime |
| 9 | `containerd config default > /etc/containerd/config.toml` | Generate containerd config |
| 10 | Set `SystemdCgroup = true` | Use systemd cgroup driver (matches kubelet) |
| 11 | `systemctl enable containerd` | Start containerd on boot |
| 12 | Add K8s apt repository | Access official K8s packages |
| 13 | `apt install kubelet kubeadm kubectl` | Install K8s components |
| 14 | `apt-mark hold kubelet kubeadm kubectl` | Prevent auto-upgrades |
| 15 | Configure kubelet resource reservations | Reserve 500Mi RAM + 200m CPU for system |
| 16 | Update `/etc/hosts` | Add hostname resolution for cluster nodes |

**Then the security role runs** (see [Security Section](#-security-implementation-4-layers) below).

---

### Play 2: Kubernetes Master Init (MASTER only)

| # | Command / Action | Purpose |
|---|------------------|---------|
| 1 | Check `/etc/kubernetes/admin.conf` | See if cluster already exists |
| 2 | `kubectl cluster-info` | Check if API server is healthy |
| 3 | `kubeadm reset -f` | Reset if cluster is corrupt |
| 4 | **`kubeadm init`** (see below) | **Initialize control plane** |
| 5 | `mkdir /root/.kube` | Setup kubectl for root |
| 6 | `cp admin.conf /root/.kube/config` | Copy kubeconfig |
| 7 | `mkdir /home/ubuntu/.kube` | Setup kubectl for ubuntu user |
| 8 | `kubectl cluster-info` | Wait for API server ready |
| 9 | `kubectl apply -f kube-flannel.yml` | **Install Flannel CNI** |
| 10 | Wait for Flannel pods Running | Verify network ready |
| 11 | `kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-` | **Allow workloads on master** (8GB optimization) |
| 12 | `kubeadm token create --print-join-command` | **Generate join command** for workers |
| 13 | `kubectl label namespace default pod-security.kubernetes.io/enforce=baseline` | **Apply Pod Security Standards** |
| 14 | Setup etcd backup cron (`0 * * * *`) | Hourly automated backups |

**The kubeadm init command:**
```bash
kubeadm init \
  --apiserver-advertise-address=192.168.144.130 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

| Parameter | Purpose |
|-----------|---------|
| `--apiserver-advertise-address` | Where API server listens (master IP) |
| `--pod-network-cidr=10.244.0.0/16` | Pod IP range — **must match Flannel's default** |
| `--service-cidr=10.96.0.0/12` | Kubernetes service IP range |
| `--cri-socket` | Use containerd (not Docker) |

---

### Play 3: Worker Join (WORKERS only)

| # | Command / Action | Purpose |
|---|------------------|---------|
| 1 | `systemctl start containerd` | Ensure runtime is running |
| 2 | Check `/etc/kubernetes/kubelet.conf` | See if already joined |
| 3 | Get join command from master (via Ansible) | Fresh token (24h expiry) |
| 4 | **`kubeadm join 192.168.144.130:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>`** | **Join cluster** |
| 5 | Wait for `kubectl get node` → Ready | Confirm node joined |

---

### Play 4: Deploy Services (MASTER, via kubectl)

```bash
# Applied in this order:
kubectl apply -f /opt/kubernetes/storage/       # StorageClass + PV + PVC
kubectl apply -f /opt/kubernetes/monitoring/     # Prometheus + Grafana + Node Exporter + KSM
kubectl apply -f /opt/kubernetes/nginx/          # Nginx Deployment + Service
kubectl apply -f /opt/kubernetes/security/       # Network Policies + RBAC
kubectl apply -f /opt/kubernetes/falco/          # Falco DaemonSet (if enabled)
```

---

## 💾 Storage: NFS Persistent Volumes

**Why NFS?** Supports `ReadWriteMany`, external to cluster, low overhead, perfect for 8GB RAM.

| PV Name | Size | PVC | NFS Path | Used By |
|---------|------|-----|----------|---------|
| `nfs-kubernetes-pv` | 10Gi | `nfs-pvc` | `/srv/nfs/kubernetes` | General data |
| `nfs-prometheus-pv` | 5Gi | `prometheus-pvc` | `/srv/nfs/kubernetes/prometheus` | Prometheus metrics |
| `nfs-grafana-pv` | 2Gi | `grafana-pvc` | `/srv/nfs/kubernetes/grafana` | Grafana dashboards |
| `nfs-nginx-pv` | 1Gi | `nginx-pvc` | `/srv/nfs/kubernetes/nginx` | Nginx web content |

**Nginx Volume Architecture:**
| Volume | Mount Path | Type | Why |
|--------|-----------|------|-----|
| `nginx-html` | `/usr/share/nginx/html` | **PVC** (`nginx-pvc`) | Web content must persist across restarts |
| `nginx-cache` | `/var/cache/nginx` | `emptyDir` | Cache is temporary, recreated per pod |
| `nginx-run` | `/var/run` | `emptyDir` | PID files are node-specific |

**Commands to verify:**
```bash
kubectl get pv                       # Check PersistentVolumes
kubectl get pvc --all-namespaces     # Check claims are Bound
kubectl describe pod -l app=nginx | grep -A10 Volumes   # Verify nginx PVC mount
```

---

## 🚀 Autoscaling Implementation (HPA & VPA)

To ensure the Nginx application can handle dynamic traffic without wasting cluster resources, I implemented a dual autoscaling approach:

### 1. Horizontal Pod Autoscaler (HPA)
**Purpose:** Scales the *number* of Nginx replicas based on CPU utilization.
- **Metric:** Targets 70% average CPU utilization across all Nginx pods.
- **Action:** If traffic spikes and CPU goes above 70%, HPA instructs the ReplicaSet to spin up more Nginx pods (e.g., matching a max of 5 replicas).
- **Why it matters:** Ensures the app remains responsive during traffic bursts without manual intervention.

### 2. Vertical Pod Autoscaler (VPA)
**Purpose:** Scales the *size* (Requests/Limits) of the Nginx containers based on historical usage.
- **Action:** Constantly monitors the actual CPU/Memory consumed by Nginx. If the container consistently needs more memory or is over-provisioned, VPA automatically updates the pod spec to the optimal size.
- **Why it matters:** Prevents "Out of Memory" (OOM) kills and ensures we aren't reserving RAM/CPU that the pod doesn't actually need.

*Note: Both HPA and VPA rely on the `metrics-server` component to function, which aggregates resource usage data directly from the kubelet on the worker nodes.*

---

## 📊 Monitoring Stack

### How it works:
```
Node Exporter (:9100, DaemonSet) ─── scrape every 30s ──→ Prometheus (:30090)
Kube-State-Metrics (:8080)       ─── scrape every 30s ──→ Prometheus
Kubernetes API (/metrics)         ─── scrape every 30s ──→ Prometheus
Falco (:8765)                     ─── scrape every 30s ──→ Prometheus
                                                              │
                                                    PromQL queries
                                                              │
                                                              ▼
                                                      Grafana (:30300)
                                                    4 pre-built dashboards
```

### Prometheus Config:
| Setting | Value | Why |
|---------|-------|-----|
| Scrape interval | 30s | Save resources (vs default 15s) |
| Retention time | 2 days | Limit disk usage |
| Retention size | 500MB | Cap storage |
| Memory limit | 256Mi | 8GB RAM optimization |
| Storage | `prometheus-pvc` (NFS 5Gi) | Data persists across restarts |

### Alert Rules I configured:
| Alert | Condition | Severity |
|-------|-----------|----------|
| **NodeDown** | Node unreachable for 2min | 🔴 Critical |
| **HighCPUUsage** | CPU > 80% for 5min | 🟡 Warning |
| **HighMemoryUsage** | Memory > 85% for 5min | 🟡 Warning |
| **DiskSpaceLow** | Disk < 15% | 🟡 Warning |
| **DiskSpaceCritical** | Disk < 5% | 🔴 Critical |
| **PodCrashLooping** | Restarts > 0.5/min for 5min | 🟡 Warning |
| **DeploymentReplicasMismatch** | Actual ≠ Desired for 10min | 🟡 Warning |
| **NginxDown** | Nginx unreachable for 2min | 🔴 Critical |
| **EtcdBackupMissing** | No backup in 2 hours | 🔴 Critical |

**Commands to verify monitoring:**
```bash
kubectl get pods -n monitoring                  # Check monitoring pods
kubectl get svc -n monitoring                   # Check service ports
curl http://192.168.144.130:30090/targets       # Prometheus scrape targets
curl http://192.168.144.130:30090/api/v1/alerts # Active alerts
```

---

## 🔒 Security Implementation (4 Layers)

### Layer 1 — Host Security (Ansible `security` role)

**UFW Firewall — Deny by default, whitelist specific ports:**

```bash
ufw default deny incoming
ufw default allow outgoing
```

| Port | Protocol | Service | Scope |
|------|----------|---------|-------|
| 22 | TCP | SSH | All nodes |
| 6443 | TCP | K8s API Server | Master only |
| 2379-2380 | TCP | etcd | Master only |
| 10250 | TCP | Kubelet API | All nodes |
| 10251 | TCP | kube-scheduler | Master only |
| 10252 | TCP | kube-controller-manager | Master only |
| 30000-32767 | TCP | NodePort Services | All nodes |
| 8472 | UDP | Flannel VXLAN | All nodes |
| 9100 | TCP | Node Exporter | All nodes |

```bash
ufw enable
ufw status verbose     # Verify rules
```

**SSH Hardening:**
```bash
# In /etc/ssh/sshd_config:
PermitRootLogin no                # No root SSH access
PasswordAuthentication no         # Key-based only
```

**Kernel Hardening:**
```bash
# sysctl parameters applied:
kernel.randomize_va_space = 2                  # ASLR enabled
net.ipv4.conf.all.rp_filter = 1               # Anti-spoofing
net.ipv4.icmp_echo_ignore_broadcasts = 1       # Ignore broadcast pings
net.ipv4.conf.all.accept_source_route = 0      # Disable source routing
net.ipv4.conf.all.send_redirects = 0           # No ICMP redirects
```

---

### Layer 2 — Kubernetes Security (RBAC + PSS)

**Pod Security Standards (PSS):**
```bash
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl label namespace default pod-security.kubernetes.io/warn=baseline --overwrite
kubectl label namespace default pod-security.kubernetes.io/audit=baseline --overwrite
```

**What `baseline` blocks:**
- ❌ `privileged: true` containers
- ❌ `hostNetwork: true`
- ❌ `hostPath` volumes
- ❌ Dangerous capabilities (`SYS_ADMIN`, `NET_ADMIN`)
- ✅ Allows non-root containers, seccomp profiles

**RBAC — Least-privilege access:**
```yaml
# Role: pod-reader (read-only pod access)
rules:
  - resources: [pods, pods/log]    verbs: [get, list, watch]
  - resources: [services]          verbs: [get, list]

# Bound to User "developer" in default namespace
```

**Commands to verify:**
```bash
kubectl get ns default --show-labels              # Check PSS labels
kubectl auth can-i list pods --as developer        # Test RBAC
kubectl run test --image=nginx --privileged=true   # Should FAIL (PSS blocks it)
```

---

### Layer 3 — Network Security (Network Policies)

```yaml
# Policy 1: Block ALL traffic to default namespace
kind: NetworkPolicy
name: default-deny-ingress
spec:
  podSelector: {}        # Applies to ALL pods
  policyTypes: [Ingress] # Deny all incoming

# Policy 2: Allow traffic to nginx on :8080 only
kind: NetworkPolicy
name: allow-nginx-ingress
spec:
  podSelector: {app: nginx}
  ingress:
    - ports: [{port: 8080}]

# Policy 3: Allow Prometheus to scrape default namespace
kind: NetworkPolicy
name: allow-prometheus-scrape
spec:
  ingress:
    - from: [{namespaceSelector: {name: monitoring}}]
```

**Commands to verify:**
```bash
kubectl get networkpolicy                    # List policies
kubectl describe networkpolicy default-deny-ingress  # See rules
```

---

### Layer 4 — Runtime Security (Falco)

**What Falco does**: Monitors Linux system calls in real-time using eBPF to detect threats.

**Deployment**: DaemonSet (runs on every node with privileged access)

**My Custom Detection Rules:**
| Rule | Priority | What It Catches |
|------|----------|-----------------|
| Shell Spawned in Container | ⚠️ WARNING | Someone runs `bash` or `sh` inside a container |
| Sensitive File Access | 🔴 CRITICAL | Process reads `/etc/shadow`, `/etc/passwd`, `admin.conf` |
| Kubectl Exec Detected | 📝 NOTICE | Someone runs `kubectl exec -it` into a container |

**Falco exports metrics to Prometheus** on port `:8765` → visible in Grafana Security Dashboard.

**Commands to verify:**
```bash
kubectl get pods -n falco                          # Check Falco running
kubectl logs -n falco -l app=falco --tail=20       # See detections
kubectl exec -it <nginx-pod> -- /bin/sh            # Trigger Falco alert, then check logs
```

---

### CIS Kubernetes Benchmark Controls Implemented

| CIS ID | Control | What I Did |
|--------|---------|------------|
| 1.1.1-1.1.21 | Control plane file permissions | `chmod 0600` on API server, etcd, scheduler manifests |
| 1.1.12 | Secure etcd data directory | `chmod 0700 /var/lib/etcd` |
| 1.1.19-21 | PKI certificate permissions | `0644` for `.crt`, `0600` for `.key` files |
| 4.1.1-5 | Worker node config security | Secure kubelet service file and config |
| 4.2.1 | Anonymous authentication | **Disabled** (`anonymous.enabled: false`) |
| 4.2.4 | Read-only port | **Disabled** (`readOnlyPort: 0`) |
| 5.2.x | Pod Security Standards | **Enforced** via namespace labels |
| 5.3.2 | Network Policies | **Applied** (default-deny + whitelist) |

---

## 🔄 Self-Healing + Reliability

**Nginx Health Probes:**
```yaml
livenessProbe:           # Restarts container if unhealthy
  httpGet:
    path: /
    port: 8080
  periodSeconds: 5
  failureThreshold: 3    # 3 failures = restart

readinessProbe:          # Removes from service if not ready
  httpGet:
    path: /
    port: 8080
  periodSeconds: 3
```

**Rolling Update Strategy (zero-downtime):**
```yaml
strategy:
  type: RollingUpdate
  maxSurge: 1            # One extra pod during update
  maxUnavailable: 0      # Never go below desired count
```

**etcd Backup (hourly, automated):**
```bash
# Cron: 0 * * * * /opt/scripts/etcd-backup.sh

# The script does:
etcdctl snapshot save /backup/etcd/etcd-snapshot-$(date).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify & copy to NFS
etcdctl snapshot status <backup-file> --write-out=table
cp <backup-file> /mnt/nfs/etcd-backups/

# Retention: 24 hourly (local), 7 daily (NFS)
```

**Commands to test self-healing:**
```bash
kubectl get pods -l app=nginx              # See 2 running pods
kubectl delete pod <nginx-pod-name>        # Delete a pod
kubectl get pods -w                        # Watch it auto-recreate (< 30 seconds)
```

---

## ✅ Post-Deployment Verification Commands

```bash
# 1. Cluster health
kubectl cluster-info
kubectl get nodes -o wide

# 2. All pods running
kubectl get pods --all-namespaces

# 3. Storage bound
kubectl get pv
kubectl get pvc --all-namespaces

# 4. Services accessible
curl http://192.168.144.130:30080    # Nginx
curl http://192.168.144.130:30090    # Prometheus
curl http://192.168.144.130:30300    # Grafana (admin/admin)

# 5. Security verification
kubectl get networkpolicy
kubectl get ns default --show-labels  # PSS labels
ufw status verbose                    # Firewall
kubectl logs -n falco -l app=falco    # Falco alerts

# 6. Test self-healing
kubectl delete pod <nginx-pod>
kubectl get pods -w

# 7. Run diagnostics script
./scripts/diagnose-services.sh
```

---

## 📈 8GB RAM Budget

| Component | RAM Usage | Notes |
|-----------|-----------|-------|
| Ubuntu OS (×2 nodes) | 500 MB × 2 | Base OS |
| Kubelet + containerd (×2) | 300 MB × 2 | Node components |
| etcd | 200 MB | Master only |
| API Server + Controller | 400 MB | Master only |
| Flannel CNI (×2) | 50 MB × 2 | Lightweight overlay |
| Prometheus | 256 MB | With retention limits |
| Grafana | 128 MB | Single instance |
| Nginx (2 pods) | 64 MB | Alpine image |
| Falco (×2) | 256 MB × 2 | DaemonSet |
| **Buffer** | 500 MB | For spikes |
| **Total** | **~4.3 GB** | Leaves headroom |

---

## 💡 Key Design Decisions to Mention

| Decision | Why |
|----------|-----|
| **Flannel over Calico** | Saves ~100MB per node (critical in 8GB) |
| **containerd over Docker** | Official CRI, lighter (~50MB), Docker deprecated in K8s 1.24+ |
| **Master taint removed** | Both nodes run workloads — maximizes 8GB RAM |
| **NFS for storage** | ReadWriteMany, external to cluster, simple |
| **Baseline PSS (not Restricted)** | Balances security with compatibility |
| **Falco DaemonSet** | Only runtime security tool that uses eBPF for syscall monitoring |
| **2-day Prometheus retention** | Prevents disk exhaustion on NFS |
| **Ansible (not Terraform)** | Configuring existing VMs, not provisioning cloud infra |

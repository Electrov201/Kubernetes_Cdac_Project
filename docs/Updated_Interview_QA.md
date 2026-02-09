# Updated Interview Q&A - Kubernetes Cluster with Ansible Automation

> **Interview Context**: Medium-level technical discussion focusing on project technologies, design decisions, and practical implementation details.

---

## Table of Contents

1. [Project Overview Questions](#1-project-overview-questions)
2. [Technology Stack & Selection](#2-technology-stack--selection)
3. [Ansible Automation](#3-ansible-automation)
4. [Kubernetes Architecture](#4-kubernetes-architecture)
5. [Monitoring Stack (Prometheus + Grafana)](#5-monitoring-stack-prometheus--grafana)
6. [Security Implementation](#6-security-implementation)
7. [Storage Configuration](#7-storage-configuration)
8. [Commands & Usage Explained](#8-commands--usage-explained)
9. [Troubleshooting & Diagnostics](#9-troubleshooting--diagnostics)
10. [Your Role & Contributions](#10-your-role--contributions)
11. [Challenges Faced & Solutions](#11-challenges-faced--solutions)
12. [HR/Behavioral Questions](#12-hrbehavioral-questions)
13. [Scenario-Based Questions](#13-scenario-based-questions)


---

## 1. Project Overview Questions

### Q: What is the main goal of your project?

**Answer**: The project automates the deployment of a **production-ready Kubernetes cluster** with complete monitoring, security, and observability using **Ansible**. It's optimized for a **2-node, 8GB RAM lab environment** while maintaining enterprise-grade practices.

**Key Features**:
| Feature | Technology | Purpose |
|---------|------------|---------|
| Automation | Ansible | One-command cluster deployment |
| Container Runtime | containerd | Lightweight, CRI-compliant |
| Networking | Flannel CNI | Simple pod overlay network |
| Monitoring | Prometheus + Grafana | Metrics collection & visualization |
| Security | UFW + RBAC + PSS + Falco | Multi-layer protection |
| Storage | NFS PersistentVolumes | Shared persistent storage |
| Backup | etcd automated backup | Hourly cluster state snapshots |

### Q: What problem does your project solve?

**Answer**: Manual Kubernetes cluster setup is:
- **Time-consuming**: 2-3 hours per cluster
- **Error-prone**: Configuration drift, missed steps
- **Inconsistent**: Different setups across environments

My project solves this by:
- **Automating everything** with a single `ansible-playbook` command
- **Ensuring consistency** through Infrastructure as Code (IaC)
- **Including observability** out-of-the-box (monitoring from day one)
- **Implementing security** following CIS Kubernetes Benchmark

---

## 2. Technology Stack & Selection

### Q: Why did you choose Ansible over other tools like Terraform?

**Answer**: 

| Criteria | Ansible | Terraform |
|----------|---------|-----------|
| **Target Use Case** | Configuration management | Infrastructure provisioning |
| **Agent Requirement** | ❌ Agentless (SSH only) | ❌ Agentless |
| **State Management** | Implicit (no state file) | Explicit (state file needed) |
| **Learning Curve** | Lower (YAML-based) | Medium (HCL language) |
| **Best For** | Server configuration, app deployment | Cloud infrastructure |

**My Reason**: Since I'm configuring **existing Ubuntu VMs** (not provisioning cloud resources), Ansible's agentless approach with SSH is more suitable. It directly configures servers without requiring state management.

### Q: Why containerd instead of Docker?

**Answer**: 

```
┌─────────────────────────────────────────────────────────────┐
│  Kubernetes v1.24+ officially removed dockershim support   │
└─────────────────────────────────────────────────────────────┘
```

| Factor | containerd | Docker |
|--------|------------|--------|
| **Memory Footprint** | ~50MB | ~100MB |
| **Docker Shim** | Not required | Required (deprecated in K8s 1.24+) |
| **CRI Compliance** | Native support | Needs dockershim |
| **Kubernetes Support** | Officially recommended | Legacy support only |

**My Reason**: containerd is **lighter**, **directly CRI-compliant**, and the **official recommendation** for Kubernetes 1.24+. With only 8GB RAM, every MB matters.

### Q: Why Flannel CNI instead of Calico?

**Answer**:

| Feature | Flannel | Calico |
|---------|---------|--------|
| **Memory Usage** | ~50MB per node | ~100-150MB per node |
| **Network Policies** | ❌ No (needs external) | ✅ Yes (built-in) |
| **Complexity** | Simple overlay (VXLAN) | Full BGP networking |
| **Best For** | Small clusters, labs | Production, multi-tenant |

**My Reason**: For a **2-node, 8GB RAM environment**, Flannel's simplicity and lower resource usage is ideal. I implement **Network Policies** separately in Kubernetes manifests, not through the CNI.

### Q: Why Prometheus + Grafana for monitoring?

**Answer**:

**Prometheus**:
- **Pull-based model**: No agents pushing data, Prometheus scrapes endpoints
- **Time-series database**: Optimized for metrics storage
- **PromQL**: Powerful query language for alerting
- **Kubernetes-native**: Built-in service discovery

**Grafana**:
- **Visualization**: Rich dashboards with graphs, alerts, heatmaps
- **Multi-datasource**: Can query Prometheus, InfluxDB, Loki, etc.
- **Pre-built dashboards**: Community templates available
- **Free and open-source**

**Alternative Considered**: ELK Stack (Elasticsearch, Logstash, Kibana)
- ❌ **Much heavier** (~2GB minimum RAM)
- ❌ **Log-focused** rather than metrics
- ❌ **Overkill** for a 2-node cluster

### Q: Why did you choose NFS for storage?

**Answer**:

| Storage Option | Pros | Cons |
|----------------|------|------|
| **NFS** | Simple, supports RWX, no vendor lock-in | Single point of failure |
| **Longhorn** | Cloud-native, replicated | Heavy (~500MB per node) |
| **Ceph** | Enterprise-grade, distributed | Very heavy, complex |
| **hostPath** | Simplest | No sharing between nodes |

**My Reason**: 
- **ReadWriteMany (RWX)** support allows shared storage
- **External to cluster** so backups are safer
- **Low overhead** suitable for my RAM constraints
- Easy to set up on an **Ubuntu NFS server**

---

## 3. Ansible Automation

### Q: Explain your Ansible playbook structure.

**Answer**:

```
ansible/
├── inventory/hosts.ini     # Target servers (IPs, roles)
├── group_vars/all.yml      # Global configuration variables
├── site.yml                # Main orchestration playbook
└── roles/
    ├── common/             # Prerequisites on ALL nodes
    ├── k8s_master/         # Control plane initialization
    ├── k8s_worker/         # Worker node join
    └── security/           # UFW, SSH hardening, CIS controls
```

**Execution Flow**:
```
site.yml
   │
   ├── Play 1: ALL nodes → common role → security role
   │
   ├── Play 2: MASTER only → k8s_master role
   │
   ├── Play 3: WORKERS only → k8s_worker role
   │
   └── Play 4: Deploy Kubernetes manifests (storage, monitoring, nginx, security)
```

### Q: What does the `common` role do?

**Answer**: Prepares ALL nodes for Kubernetes:

| Step | Action | Why Needed |
|------|--------|------------|
| 1 | `swapoff -a` | K8s requires swap disabled |
| 2 | Load `overlay`, `br_netfilter` modules | Container networking |
| 3 | Set sysctl params | IP forwarding, bridge filtering |
| 4 | Install containerd | Container runtime |
| 5 | Configure cgroup driver | systemd cgroup for kubelet |
| 6 | Add K8s apt repository | Access kubelet, kubeadm, kubectl |
| 7 | Install K8s components | kubelet, kubeadm, kubectl |
| 8 | Hold package versions | Prevent auto-upgrades |
| 9 | Configure kubelet | Memory/CPU reservations |
| 10 | Update /etc/hosts | Node hostname resolution |

### Q: What does the `security` role do?

**Answer**: Implements multi-layer security:

**1. Firewall (UFW)**:
| Port | Service | Scope |
|------|---------|-------|
| 22 | SSH | All nodes |
| 6443 | K8s API Server | Master only |
| 2379-2380 | etcd | Master only |
| 10250 | Kubelet API | All nodes |
| 30000-32767 | NodePorts | All nodes |
| 8472/UDP | Flannel VXLAN | All nodes |

**2. SSH Hardening**:
- `PermitRootLogin no`
- `PasswordAuthentication no`

**3. CIS Kubernetes Benchmark Controls**:
- Secure file permissions on manifests (0600)
- Disable anonymous kubelet authentication
- Disable kubelet read-only port

**4. Kernel Hardening**:
- `kernel.randomize_va_space=2` (ASLR)
- Disable IP source routing
- Enable reverse path filtering

---

## 4. Kubernetes Architecture

### Q: Explain the kubeadm init command in your project.

**Answer**:

```bash
kubeadm init \
  --apiserver-advertise-address=192.168.144.130 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `--apiserver-advertise-address` | Master IP | Where API server listens |
| `--pod-network-cidr` | 10.244.0.0/16 | Pod IP range (Flannel default) |
| `--service-cidr` | 10.96.0.0/12 | Kubernetes service IPs |
| `--cri-socket` | containerd socket | Container runtime interface |

**What happens during init**:
1. Generates PKI certificates
2. Creates static pod manifests for control plane
3. Starts etcd (cluster state database)
4. Starts API server, scheduler, controller-manager
5. Generates bootstrap token for workers

### Q: How do worker nodes join the cluster?

**Answer**:

```bash
kubeadm join 192.168.144.130:6443 \
  --token <bootstrap-token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --cri-socket=unix:///run/containerd/containerd.sock
```

| Parameter | Purpose |
|-----------|---------|
| `192.168.144.130:6443` | Master's API server endpoint |
| `--token` | Bootstrap token (valid 24h by default) |
| `--discovery-token-ca-cert-hash` | Validates the master's CA certificate |
| `--cri-socket` | Use containerd as runtime |

**Join Process**:
1. Worker contacts API server with token
2. Downloads cluster configuration
3. kubelet registers node with API server
4. Node becomes Ready when CNI initializes

### Q: Why did you remove the NoSchedule taint from master?

**Answer**:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

**Default Behavior**: Master nodes have a `NoSchedule` taint preventing workloads.

**In 8GB, 2-node setup**: With limited resources, I need to use the master for workloads too. Removing the taint allows:
- Monitoring pods to run on master
- Nginx replicas to spread across both nodes
- Better resource utilization

---

## 5. Monitoring Stack (Prometheus + Grafana)

### Q: Explain how Prometheus collects metrics.

**Answer**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    PULL-BASED ARCHITECTURE                      │
│                                                                 │
│   Node Exporter (:9100) ──────┐                                │
│   Kube-State-Metrics (:8080) ─┼──→ Prometheus ──→ Grafana      │
│   Kubernetes API (/metrics) ──┤       ↓                        │
│   Falco (:8765) ──────────────┘   Alert Rules                  │
└─────────────────────────────────────────────────────────────────┘
```

**Scrape Configuration (`prometheus.yml`)**:

| Job Name | Target | Metrics Collected |
|----------|--------|-------------------|
| `prometheus` | localhost:9090 | Self-monitoring |
| `kubernetes-apiservers` | K8s API | API server health |
| `kubernetes-nodes` | All nodes | kubelet metrics |
| `node-exporter` | :9100 on nodes | CPU, RAM, disk |
| `kube-state-metrics` | :8080 | Pod, deployment state |
| `falco` | :8765 | Security events |

### Q: What is Node Exporter and why is it needed?

**Answer**:

**Node Exporter** is a Prometheus exporter that collects **hardware and OS-level metrics**.

| Metric | Example | Use Case |
|--------|---------|----------|
| `node_cpu_seconds_total` | CPU usage per core | High CPU alerts |
| `node_memory_MemAvailable_bytes` | Free memory | OOM prevention |
| `node_filesystem_avail_bytes` | Disk space | Disk full alerts |
| `node_network_receive_bytes_total` | Network I/O | Traffic monitoring |

**Deployment Type**: DaemonSet (runs on every node automatically)

**Why Needed**: Prometheus doesn't natively know host metrics. Node Exporter exposes them in Prometheus format.

### Q: What is Kube-State-Metrics?

**Answer**:

**Kube-State-Metrics** generates metrics about **Kubernetes object states** (not resource usage).

| Without KSM | With KSM |
|-------------|----------|
| No pod count | `kube_pod_status_phase{phase="Running"}` |
| No deployment info | `kube_deployment_status_replicas` |
| Grafana shows "No Data" | Full K8s visibility |

**Key Metrics**:
- `kube_pod_container_status_restarts_total` - Container restarts
- `kube_deployment_status_available_replicas` - Available replicas
- `kube_node_status_condition{condition="Ready"}` - Node health

### Q: Explain your alerting configuration.

**Answer**: Defined in `prometheus-alerts.yaml`:

**Node Alerts**:
| Alert | Condition | Severity |
|-------|-----------|----------|
| NodeDown | Node unreachable | Critical |
| HighCPUUsage | CPU > 80% for 5min | Warning |
| HighMemoryUsage | Memory > 85% for 5min | Warning |
| DiskSpaceLow | Disk < 15% | Warning |

**Kubernetes Alerts**:
| Alert | Condition | Severity |
|-------|-----------|----------|
| PodCrashLooping | Restarts > 0.5/min for 5min | Warning |
| DeploymentReplicasMismatch | Actual ≠ Desired for 10min | Warning |

---

## 6. Security Implementation

### Q: Explain your multi-layer security approach.

**Answer**:

```
Layer 1: NODE SECURITY
├── UFW Firewall (deny by default)
├── SSH hardening (key-only, no root)
└── Kernel parameters (ASLR, rp_filter)

Layer 2: KUBERNETES SECURITY
├── Pod Security Standards (baseline)
├── RBAC (least-privilege access)
└── ServiceAccount restrictions

Layer 3: NETWORK SECURITY
├── Network Policies (default-deny)
└── Namespace isolation

Layer 4: RUNTIME SECURITY
├── Falco (syscall monitoring)
└── Container SecurityContext
```

### Q: What are Pod Security Standards (PSS)?

**Answer**: PSS replaced the deprecated PodSecurityPolicies in Kubernetes 1.25.

| Level | Description | Restrictions |
|-------|-------------|--------------|
| **Privileged** | No restrictions | None |
| **Baseline** | Minimally restrictive | Blocks host namespaces, privileged containers |
| **Restricted** | Heavily restricted | Requires non-root, drops all capabilities |

**Applied via namespace labels**:
```bash
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline
```

**What baseline blocks**:
- `privileged: true` containers
- `hostNetwork: true`
- `hostPath` volumes
- Dangerous capabilities (SYS_ADMIN, NET_ADMIN)

### Q: What is Falco and how does it work?

**Answer**:

**Falco** is a **runtime security tool** that monitors system calls to detect threats.

**How It Works**:
```
Container Process
      ↓
System Calls (open, execve, read, write)
      ↓
Falco intercepts using eBPF/kernel module
      ↓
Matches against detection rules
      ↓
Generates alerts (stdout, metrics, file)
```

**My Custom Rules**:

| Rule | Priority | What It Detects |
|------|----------|-----------------|
| Shell Spawned in Container | WARNING | bash/sh/zsh execution |
| Sensitive File Access | CRITICAL | Reading /etc/shadow, admin.conf |
| Kubectl Exec Detected | NOTICE | Interactive kubectl exec |

**Deployment**: DaemonSet (runs on every node with privileged access)

### Q: Explain Network Policy in your project.

**Answer**:

```yaml
# 1. Default deny all ingress to default namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress

# 2. Allow ingress to nginx on port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx-ingress
spec:
  podSelector:
    matchLabels:
      app: nginx
  ingress:
    - ports:
        - port: 8080
```

**Effect**: Block everything by default, then whitelist specific traffic.

---

## 7. Storage Configuration

### Q: Explain PV and PVC in your project.

**Answer**:

**PersistentVolume (PV)**: Cluster resource representing actual storage
**PersistentVolumeClaim (PVC)**: Request for storage by a pod

```
NFS Server (/srv/nfs/kubernetes/prometheus)
         ↓
    PV: nfs-prometheus-pv (5Gi)
         ↓
    PVC: prometheus-pvc
         ↓
    Prometheus Pod uses for /prometheus data
```

**My PV/PVC Configuration**:

| PV Name | Capacity | Bound PVC | Purpose |
|---------|----------|-----------|---------|
| nfs-prometheus-pv | 5Gi | prometheus-pvc | Metrics storage |
| nfs-grafana-pv | 2Gi | grafana-pvc | Dashboard config |
| nfs-nginx-pv | 1Gi | nginx-pvc | Web content |

**Access Mode**: `ReadWriteMany (RWX)` - Multiple pods can mount simultaneously

---

## 8. Commands & Usage Explained

### Ansible Commands

| Command | Purpose |
|---------|---------|
| `ansible-playbook -i inventory/hosts.ini site.yml` | Full cluster deployment |
| `ansible-playbook -i inventory/hosts.ini site.yml --tags common` | Run only common role |
| `ansible-playbook site.yml --check` | Dry run (no changes) |
| `ansible-playbook site.yml -vvv` | Verbose output |

### kubectl Commands

| Command | Purpose |
|---------|---------|
| `kubectl get nodes -o wide` | List nodes with IPs |
| `kubectl get pods --all-namespaces` | All pods in cluster |
| `kubectl describe pod <name>` | Pod details, events |
| `kubectl logs <pod>` | Container logs |
| `kubectl apply -f manifest.yaml` | Create/update resources |
| `kubectl delete pod <name>` | Delete pod (test self-healing) |
| `kubectl exec -it <pod> -- /bin/sh` | Shell into container |
| `kubectl scale deployment nginx --replicas=5` | Scale deployment |

### kubeadm Commands

| Command | Purpose |
|---------|---------|
| `kubeadm init` | Initialize control plane |
| `kubeadm join` | Join worker to cluster |
| `kubeadm token create --print-join-command` | Generate new join token |
| `kubeadm reset -f` | Tear down node completely |

### etcd Commands

| Command | Purpose |
|---------|---------|
| `etcdctl snapshot save backup.db` | Create etcd backup |
| `etcdctl snapshot status backup.db` | Verify backup |
| `etcdctl snapshot restore backup.db` | Restore from backup |

### System Commands Used

| Command | Purpose | Why Used |
|---------|---------|----------|
| `swapoff -a` | Disable swap | K8s requirement |
| `modprobe overlay` | Load kernel module | Container networking |
| `sysctl -w net.ipv4.ip_forward=1` | Enable IP forwarding | Pod-to-pod communication |
| `ufw enable` | Enable firewall | Security |
| `systemctl restart kubelet` | Restart kubelet | Apply config changes |

---

## 9. Troubleshooting & Diagnostics

### Q: How do you diagnose service issues?

**Answer**: I created `diagnose-services.sh` that checks:

| Check | Command | Looking For |
|-------|---------|-------------|
| Cluster connectivity | `kubectl cluster-info` | API server accessible |
| Node status | `kubectl get nodes` | All nodes Ready |
| PVC binding | `kubectl get pvc` | All PVCs Bound |
| Pod health | `kubectl get pods` | All Running |
| Service endpoints | `kubectl get endpoints` | IPs assigned |
| Firewall | `ufw status` | Required ports open |
| NFS connectivity | `ping nfs-server` | Storage accessible |

### Q: Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Pods stuck in Pending | No nodes schedulable | Remove master taint or check resources |
| PVC stuck in Pending | No matching PV | Check PV labels, storage class |
| Node NotReady | CNI not running | Check Flannel pods, network connectivity |
| ImagePullBackOff | Can't pull image | Check internet, registry |
| CrashLoopBackOff | Container crashing | `kubectl logs <pod>` for details |

### Q: What's in your etcd backup script?

**Answer**:

```bash
# Take snapshot
etcdctl snapshot save \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  /backup/etcd/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db

# Retention: 24 hourly local, 7 days on NFS
```

**Automated via cron**: `0 * * * *` (every hour)

---

## Quick Reference Card

### Services Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Prometheus | http://192.168.144.130:30090 | None |
| Grafana | http://192.168.144.130:30300 | admin/admin |
| Nginx | http://192.168.144.130:30080 | None |

### Key Configuration Variables (`all.yml`)

| Variable | Value | Purpose |
|----------|-------|---------|
| `kubernetes_version` | 1.29 | K8s version |
| `cni_plugin` | flannel | Network plugin |
| `pss_level` | baseline | Pod security level |
| `enable_falco` | true | Runtime security |
| `allow_master_scheduling` | true | Use master for workloads |

---

## Summary: Why These Technologies?

| Technology | Why Chosen |
|------------|------------|
| **Ansible** | Agentless, YAML-based, ideal for server configuration |
| **containerd** | Lightweight, official CRI, K8s 1.24+ compatible |
| **Flannel** | Simple, low memory, perfect for small clusters |
| **Prometheus** | Cloud-native, pull-based, powerful PromQL |
| **Grafana** | Beautiful dashboards, free, integrates with Prometheus |
| **NFS** | Simple shared storage, RWX support, external to cluster |
| **Falco** | Runtime security, syscall monitoring, Prometheus integration |
| **UFW** | Simple firewall, Ubuntu native |
| **PSS** | Official K8s security, replaces deprecated PSP |

---

## 10. Your Role & Contributions (Team of 5)

### Q: Was this an individual or team project?

**Answer**: This was a **team project with 5 members**. We divided responsibilities based on each member's strengths and interests.

### Q: How was the work distributed among team members?

**Answer**:

| Team Member | Role | Primary Responsibilities |
|-------------|------|--------------------------|
| **Member 1 (Me)** | DevOps Engineer / Team Lead | Ansible automation, Kubernetes manifests, project coordination |
| **Member 2** | Infrastructure Engineer | VM setup, NFS server configuration, network configuration |
| **Member 3** | Monitoring Specialist | Prometheus configuration, Grafana dashboards, alerting rules |
| **Member 4** | Security Engineer | UFW firewall, CIS benchmark implementation, Falco setup |
| **Member 5** | Documentation & Testing | Setup guides, testing, troubleshooting scripts |

### Q: What was YOUR specific role?

**Answer**: I was the **DevOps Engineer and Team Lead** responsible for:

1. **Project Coordination**: Organized tasks, tracked progress, resolved blockers
2. **Ansible Automation**: Designed the role-based structure (`common`, `k8s_master`, `k8s_worker`)
3. **Kubernetes Manifests**: Created deployment manifests for nginx, storage configuration
4. **Integration**: Ensured all team members' work integrated properly
5. **Code Review**: Reviewed and merged contributions from team members

### Q: What specific contributions did you make?

**Answer**:

| Area | My Contribution |
|------|-----------------|
| **Ansible Structure** | Designed 4-role architecture, wrote `site.yml` orchestration |
| **Kubernetes Core** | Created storage manifests (PV/PVC), nginx deployment with health probes |
| **Integration** | Connected monitoring → alerting → storage components |
| **Troubleshooting** | Created `diagnose-services.sh` script |
| **Resource Optimization** | Tuned components for 8GB RAM constraints |

### Q: How did the team collaborate?

**Answer**: We followed an **agile approach**:

```
Weekly Workflow:
├── Monday: Sprint planning, task assignment
├── Daily: 15-min standups (progress + blockers)
├── Wednesday: Integration testing
├── Friday: Demo + retrospective
└── Git: Feature branches → Pull requests → Code review → Merge
```

**Tools Used**:
- **Git/GitHub**: Version control, pull requests
- **Slack/Discord**: Daily communication
- **Shared VMs**: Testing environment

### Q: How did you handle disagreements in the team?

**Answer**: We had a democratic approach:

1. **Discuss options**: Each member presents their reasoning
2. **Evaluate trade-offs**: Consider resource usage, complexity, maintainability
3. **Prototype if needed**: Quick test to validate approach
4. **Team vote**: Majority decides, but respect minority concerns
5. **Document decisions**: Record why we chose specific approaches

**Example**: When choosing between Flannel and Calico:
- Member 4 preferred Calico for built-in Network Policies
- I advocated for Flannel due to memory constraints
- We tested both and saw Calico used 100MB more per node
- **Decision**: Flannel + separate Network Policy manifests

### Q: What did you learn from working in a team?

**Answer**:

| Skill | Learning |
|-------|----------|
| **Communication** | Clear documentation is essential for handoffs |
| **Code Review** | Others catch issues I miss |
| **Delegation** | Trust teammates with their assigned areas |
| **Conflict Resolution** | Data-driven decisions reduce arguments |
| **Integration** | Coordinate interfaces between components early |

---

## 11. Challenges Faced & Solutions

### Challenge 1: Cluster Initialization Failures

**Problem**: `kubeadm init` was failing with "API server not responding" errors.

**Root Cause**: Swap was not fully disabled, `/etc/fstab` still had swap entries.

**Solution**:
```yaml
# In common role - ensure both commands run
- name: Disable swap immediately
  command: swapoff -a

- name: Disable swap permanently
  replace:
    path: /etc/fstab
    regexp: '^([^#].*?\sswap\s+sw\s+.*)$'
    replace: '# \1'
```

**Learning**: Always handle both runtime AND persistent configuration.

---

### Challenge 2: Flannel Pods Stuck in Init:0/1

**Problem**: After `kubeadm init`, Flannel pods were stuck in `Init:0/1` state.

**Root Cause**: The `net.bridge.bridge-nf-call-iptables` sysctl parameter wasn't applied before Flannel started.

**Solution**:
```yaml
# Ensure kernel modules loaded BEFORE sysctl
- name: Load required kernel modules
  modprobe:
    name: "{{ item }}"
  loop:
    - overlay
    - br_netfilter

# Then apply sysctl
- name: Configure sysctl parameters
  sysctl:
    name: net.bridge.bridge-nf-call-iptables
    value: '1'
    reload: yes
```

**Learning**: Order of operations matters in automation. Kernel modules must be loaded before sysctl parameters that depend on them.

---

### Challenge 3: PVCs Stuck in Pending State

**Problem**: PersistentVolumeClaims were not binding to PersistentVolumes.

**Root Cause**: PV labels didn't match PVC selector, and storage class name was different.

**Solution**:
```yaml
# PV must have labels that PVC selector can match
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-prometheus-pv
  labels:
    app: prometheus  # Add label
spec:
  storageClassName: nfs-storage

# PVC must use selector
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
spec:
  storageClassName: nfs-storage  # Must match
  selector:
    matchLabels:
      app: prometheus  # Must match PV label
```

**Learning**: Static PV provisioning requires careful label/selector matching.

---

### Challenge 4: Node Exporter Not Exposing Metrics

**Problem**: Prometheus couldn't scrape Node Exporter on port 9100.

**Root Cause**: Node Exporter pod was running but not binding to host network.

**Solution**:
```yaml
# DaemonSet must use hostNetwork
spec:
  template:
    spec:
      hostNetwork: true  # Bind to node's network
      hostPID: true      # Access process info
      containers:
        - name: node-exporter
          ports:
            - containerPort: 9100
              hostPort: 9100  # Expose on node IP
```

**Learning**: For system-level metrics, DaemonSets need host network access.

---

### Challenge 5: Worker Node Couldn't Join After Token Expired

**Problem**: 24 hours after master init, worker join failed with "token invalid".

**Root Cause**: Bootstrap tokens expire after 24 hours by default.

**Solution**: Added task in Ansible to generate fresh token:
```yaml
- name: Generate fresh join command
  shell: kubeadm token create --print-join-command
  register: join_command_raw
  delegate_to: "{{ groups['masters'][0] }}"
```

**Learning**: In automation, always generate fresh tokens instead of storing old ones.

---

### Challenge 6: 8GB RAM Exhaustion

**Problem**: Cluster was running out of memory after deploying monitoring.

**Root Cause**: Default Prometheus settings were too aggressive.

**Solution**: Optimized resource limits and retention:
```yaml
# Reduced Prometheus retention and limits
containers:
  - name: prometheus
    args:
      - '--storage.tsdb.retention.time=2d'   # Was 15d
      - '--storage.tsdb.retention.size=500MB' # Was unlimited
    resources:
      limits:
        memory: "256Mi"  # Was 1Gi
```

**Learning**: Always consider resource constraints from the start, not after problems occur.

---

### Challenge 7: Grafana Showing "No Data" for Kubernetes Metrics

**Problem**: CPU/Memory dashboards worked, but pod/deployment metrics showed "No Data".

**Root Cause**: Kube-State-Metrics wasn't deployed. Prometheus only had node metrics, not K8s object state.

**Solution**: Added Kube-State-Metrics deployment with proper RBAC:
```yaml
# ServiceAccount with ClusterRole to read K8s objects
- apiGroups: [""]
  resources: [pods, nodes, services, ...]
  verbs: [get, list, watch]
```

**Learning**: Node Exporter ≠ Kubernetes metrics. KSM is essential for K8s object monitoring.

---

### Challenge 8: CIS Security Controls Breaking kubelet

**Problem**: After applying CIS 4.2.6 (`protectKernelDefaults: true`), kubelet wouldn't start.

**Root Cause**: The setting requires specific kernel parameters that weren't all set.

**Solution**: Disabled this specific control with documentation:
```yaml
# Set to false for compatibility - document the tradeoff
- name: CIS 4.2.6 - Set protectKernelDefaults
  lineinfile:
    path: /var/lib/kubelet/config.yaml
    line: 'protectKernelDefaults: false'  # Disabled for VM compatibility
```

**Learning**: Security best practices may conflict with specific environments. Document tradeoffs.

---

## 12. HR/Behavioral Questions

### Q: Why did you choose this project?

**Answer**: I wanted to gain hands-on experience with:
- **Kubernetes administration** - not just using it, but setting it up from scratch
- **Infrastructure as Code** - automating repetitive tasks with Ansible
- **DevOps practices** - monitoring, security, and backup automation

This project combines all these skills in a practical, deployable solution.

### Q: What did you learn from this project?

**Answer**:

| Skill Area | What I Learned |
|------------|----------------|
| **Kubernetes** | Control plane components, networking, storage, security |
| **Ansible** | Role-based structure, idempotency, handlers, variables |
| **Monitoring** | Time-series databases, PromQL, Grafana dashboards |
| **Security** | CIS benchmarks, Pod Security Standards, runtime security |
| **Troubleshooting** | Debugging pods, analyzing logs, network issues |
| **Resource Management** | Optimizing for constrained environments |

### Q: How would you improve this project?

**Answer**: Future enhancements I would make:

1. **High Availability**: Add multiple master nodes with HAProxy
2. **Horizontal Pod Autoscaling**: Deploy Metrics Server and HPA
3. **GitOps**: Integrate ArgoCD for declarative deployments
4. **Log Management**: Add Loki for log aggregation
5. **Ingress Controller**: Replace NodePorts with Nginx Ingress
6. **Secrets Management**: Integrate HashiCorp Vault

### Q: How did you handle the pressure of troubleshooting?

**Answer**: I followed a **systematic approach**:

1. **Isolate the problem**: Which component is failing?
2. **Check logs**: `kubectl logs`, `journalctl -u kubelet`
3. **Verify dependencies**: Is the service it depends on running?
4. **Compare with documentation**: Am I following the right configuration?
5. **Search for similar issues**: Check GitHub issues, Stack Overflow
6. **Create diagnostic script**: I captured my troubleshooting steps in `diagnose-services.sh`

### Q: How do you stay updated with DevOps technologies?

**Answer**:
- **Official documentation**: Kubernetes.io, Ansible docs
- **Community resources**: CNCF blogs, DevOps Weekly newsletter
- **Hands-on practice**: This project itself!
- **Certifications**: Studying for CKA (Certified Kubernetes Administrator)

---

## 13. Scenario-Based Questions

### Q: If the master node goes down, what happens?

**Answer**:

| Component | Impact | Recovery |
|-----------|--------|----------|
| **API Server** | No new deployments, no kubectl access | Restart master, API recovers from etcd |
| **Scheduler** | No new pods scheduled | Backlog processed after restart |
| **Controller Manager** | No self-healing | Catches up after restart |
| **etcd** | Cluster state unavailable | Restore from backup if corrupted |
| **Worker Pods** | Continue running (isolated) | Reconnect when master is back |

**My Backup Strategy**: Hourly etcd snapshots to NFS server for disaster recovery.

---

### Q: How would you scale this cluster for production?

**Answer**:

| Current | Production |
|---------|------------|
| 2 nodes | 3+ masters (HA), 3+ workers |
| NodePort | Ingress Controller + LoadBalancer |
| 8GB RAM | 16GB+ per node |
| Flannel | Calico (for Network Policies) |
| emptyDir for Prometheus | PersistentVolume with proper retention |
| Single NFS | Replicated storage (Ceph, Longhorn) |

---

### Q: A pod is crashing repeatedly. How do you debug?

**Answer**: My debugging workflow:

```bash
# 1. Check pod status
kubectl get pods -o wide

# 2. See why it's failing
kubectl describe pod <pod-name>

# 3. Check logs (current and previous)
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# 4. Check events
kubectl get events --sort-by=.lastTimestamp

# 5. If needed, exec into a debug container
kubectl debug -it <pod-name> --image=busybox

# 6. Check resource limits
kubectl top pod <pod-name>
```

---

### Q: How would you implement zero-downtime deployments?

**Answer**: Already implemented in my nginx deployment:

```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # One extra pod during update
      maxUnavailable: 0  # Never reduce below desired
  template:
    spec:
      containers:
        - readinessProbe:  # Only receive traffic when ready
            httpGet:
              path: /
              port: 8080
```

**How it works**:
1. New pod created
2. Wait for readiness probe to pass
3. Add to service endpoints
4. Remove old pod from endpoints
5. Terminate old pod
6. Repeat for remaining replicas

---

### Q: Someone accidentally deleted a namespace. How do you recover?

**Answer**:

**Prevention** (already implemented):
- RBAC limits who can delete namespaces
- `ResourceQuota` on namespaces

**Recovery**:
```bash
# If etcd backup exists:
etcdctl snapshot restore /backup/etcd/latest.db \
  --data-dir=/var/lib/etcd-restored

# Then re-apply manifests
kubectl apply -f /opt/kubernetes/

# If no backup, redeploy from git repository
ansible-playbook -i inventory/hosts.ini site.yml --tags deploy_services
```

---

### Q: How do you ensure security in a shared Kubernetes cluster?

**Answer**: My multi-layer approach:

```
1. NAMESPACE ISOLATION
   └── Each team gets their own namespace

2. RBAC
   └── Least-privilege access per team
   └── No cluster-admin for developers

3. NETWORK POLICIES
   └── default-deny ingress per namespace
   └── Explicit allow rules only

4. POD SECURITY STANDARDS
   └── baseline or restricted level enforcement

5. RESOURCE QUOTAS
   └── CPU/memory limits per namespace

6. RUNTIME SECURITY
   └── Falco alerts on suspicious activity
```

---

## Quick Tips for the Interview

### ✅ DO:
- Explain **why** you chose each technology
- Mention specific **challenges** and how you solved them
- Show **understanding** of tradeoffs
- Demonstrate **hands-on experience** with commands
- Be honest about **limitations** and future improvements

### ❌ DON'T:
- Just list technologies without explaining usage
- Claim everything worked perfectly the first time
- Pretend to know something you don't
- Over-engineer answers for a simple question

### 💡 Key Points to Emphasize:
1. **Resource optimization** for 8GB RAM
2. **Security-first approach** with CIS benchmarks
3. **Automation mindset** with Ansible
4. **Observability** built-in from day one
5. **Practical troubleshooting** experience

---

*Document updated: February 10, 2026*
*Project: Kubernetes Cluster Setup with Ansible Automation*
*Role: DevOps Engineer*

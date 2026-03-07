# 🎤 Complete Interview Guide — Kubernetes Cluster Project

> **One document. Every question. Every answer.**
> Combines all interview preparation into a single reference — project pitch, technical deep-dives, scenario questions, story mode, HR prep, and quick reference.

---

## 📋 Table of Contents

| # | Section | What It Covers |
|---|---------|----------------|
| 1 | [Project Pitch](#1-project-pitch) | 60-second elevator pitch + follow-up answers |
| 2 | [Business Value](#2-business-value--real-world-problems) | Why this project matters to companies |
| 3 | [Architecture & Flow](#3-architecture--deployment-flow) | How the cluster works end-to-end |
| 4 | [Ansible Q&A](#4-ansible--automation-qa) | Roles, idempotency, commands |
| 5 | [Kubernetes Core Q&A](#5-kubernetes-core-qa) | Pods, Deployments, Services, Namespaces |
| 6 | [Storage Q&A](#6-storage-qa) | NFS, PV, PVC, StorageClass |
| 7 | [Monitoring Q&A](#7-monitoring-qa) | Prometheus, Grafana, Alerting |
| 8 | [Security Q&A](#8-security-qa) | RBAC, PSS, Network Policies, Falco, Secrets |
| 9 | [Autoscaling Q&A](#9-autoscaling-qa) | HPA, metrics-server, VPA |
| 10 | [Self-Healing & Reliability](#10-self-healing--reliability-qa) | Probes, rolling updates, backups |
| 11 | [Troubleshooting Q&A](#11-troubleshooting-qa) | Debugging pods, common issues |
| 12 | [Scenario-Based Q&A](#12-scenario-based-qa) | "What if..." production scenarios |
| 13 | [Story Mode](#13-story-mode) | How I built this + user request flow |
| 14 | [Challenges Faced](#14-challenges-faced--solutions) | Real problems and how I solved them |
| 15 | [Team & Collaboration](#15-team--collaboration) | Team of 5, roles, Agile workflow |
| 16 | [HR & Behavioral](#16-hr--behavioral-questions) | Why this project, learnings, improvements |
| 17 | [General IT & Security](#17-general-it--security-concepts) | DNS, OSI, networking, web security |
| 18 | [Quick Reference Card](#18-quick-reference-card) | Commands, URLs, key facts |

---

## 1. Project Pitch

### "Tell me about your project" (60-second version)

> "I automated the deployment of a **production-ready Kubernetes cluster** using **Ansible**. With a single command — `ansible-playbook site.yml` — it sets up a complete cluster on Ubuntu 22.04 VMs with:
> - A **Master-Worker architecture** using kubeadm
> - **Persistent NFS storage** for data that survives pod restarts
> - **Full observability** with Prometheus and Grafana (4 pre-built dashboards)
> - **Multi-layer security** — firewall, RBAC, Network Policies, Pod Security Standards, and Falco runtime detection
> - **Autoscaling** with HPA and auto-deployed metrics-server
> - **Automated etcd backups** for disaster recovery
> 
> Everything runs on an **8GB RAM, 2-node environment**, optimized for resource constraints while maintaining production-grade practices."

### Follow-Up Questions Table

| You said... | Interviewer asks... | Your answer |
|---|---|---|
| **"Ansible"** | *What Ansible command?* | "I structured roles (`common`, `k8s_master`, `k8s_worker`, `security`) and ran: `ansible-playbook -i inventory/hosts.ini site.yml`. It handles everything via SSH — agentless." |
| **"Master-Worker"** | *What runs on each?* | "Master runs API Server (:6443), etcd, Scheduler, Controller Manager. Workers run kubelet, kube-proxy, containerd. Flannel CNI handles pod networking." |
| **"Persistent storage"** | *How does NFS work?* | "External NFS server at 192.168.144.132. PersistentVolumes point to NFS paths, PVCs bind to them. Prometheus (5Gi), Grafana (2Gi), Nginx (1Gi) all persist data across restarts." |
| **"Prometheus + Grafana"** | *What metrics?* | "Node Exporter for hardware metrics, Kube-State-Metrics for K8s objects, kubelet for container metrics, Falco for security events. All scraped every 30s." |
| **"Multi-layer security"** | *How many layers?* | "4 layers: (1) Host — UFW + SSH hardening + CIS benchmarks, (2) K8s — RBAC + PSS baseline, (3) Network — 6 NetworkPolicies (deny ingress+egress by default), (4) Runtime — Falco syscall monitoring." |
| **"Autoscaling"** | *How does HPA work?* | "Metrics-server is auto-deployed by Ansible. HPA watches nginx CPU (>70%) and memory (>80%). Scales from 2 to 5 replicas. Conservative scale-down with 5-minute window." |
| **"Falco"** | *How does it detect threats?* | "Falco runs as a privileged DaemonSet. It uses eBPF probes attached to the Linux kernel to intercept syscalls — detects shell spawning, sensitive file access, kubectl exec." |

---

## 2. Business Value & Real-World Problems

### "Why does this project matter?"

| Problem | Without This Project | With This Project |
|---------|---------------------|-------------------|
| **Cluster setup** | 4-6 hours, error-prone | 30 minutes, consistent |
| **Compliance audit** | Manual evidence gathering | Codified policies, instant audit |
| **Knowledge transfer** | Tribal knowledge | Self-documenting code |
| **Incident detection** | Reactive (after users complain) | Proactive (metrics & alerts) |
| **Disaster recovery** | No backup, total loss risk | Automated, tested recovery |
| **Security posture** | Default settings (weak) | CIS hardened + runtime detection |

### Key Metrics to Mention
- **Deployment time**: 4-6 hours manual → 30 minutes automated
- **Human errors eliminated**: 100% (no manual steps)
- **MTTR**: Reduced with etcd backups (RTO: ~30 min)
- **Compliance coverage**: 15+ CIS benchmark controls
- **Security layers**: 4 (Host → K8s → Network → Runtime)

### Real-World Problems Solved

**1. Compliance & Audit** — CIS benchmarks are codified in Ansible. Auditors review `security/tasks/main.yml` instead of interviewing engineers.

**2. Knowledge Transfer** — All configurations are in readable YAML files. No dependency on any person's memory.

**3. Vendor Lock-in Prevention** — Uses standard kubeadm. Same playbooks work on AWS, Azure, on-prem, or bare metal.

**4. Downtime Cost Reduction** — Proactive monitoring catches issues before users notice. Self-healing pods restart automatically.

**5. Security Incident Prevention** — PSS prevents privileged containers. Network Policies implement zero-trust. Falco detects runtime threats.

**6. Disaster Recovery** — Automated etcd backups every hour. Documented restore procedure. Off-site storage to NFS.

**7. Environment Consistency** — Same Ansible playbook for dev/staging/prod. Only variables change.

---

## 3. Architecture & Deployment Flow

### Cluster Architecture
```
ANSIBLE CONTROL MACHINE
       │
       │  $ ansible-playbook -i inventory/hosts.ini site.yml
       │
       ├── SSH ── MASTER NODE (192.168.144.130) ── 4GB RAM
       │           ├── API Server (:6443)
       │           ├── etcd (:2379)
       │           ├── Scheduler
       │           └── Controller Manager
       │
       └── SSH ── WORKER NODE (192.168.144.134) ── 4GB RAM
                   ├── kubelet
                   ├── kube-proxy
                   └── containerd

DEPLOYED SERVICES:
┌─────────────────────────────────────┐
│ Prometheus :30090  │ Grafana :30300 │
│ Nginx x2   :30080  │ Falco         │
│ Node Exporter      │ KSM           │
│ HPA + metrics-server               │
└──────────────┬──────────────────────┘
               │ PVC (NFS)
               ▼
   NFS SERVER (192.168.144.132)
   ├── /srv/nfs/kubernetes/prometheus  (5Gi)
   ├── /srv/nfs/kubernetes/grafana     (2Gi)
   ├── /srv/nfs/kubernetes/nginx       (1Gi)
   └── /srv/nfs/etcd-backups
```

### Deployment Order (Play 4 — What Gets Applied)
```bash
kubectl apply -f /opt/kubernetes/storage/               # 1. StorageClass + PV + PVC
kubectl apply -f /opt/kubernetes/monitoring/grafana-secret.yaml  # 2. Grafana credentials
kubectl apply -f /opt/kubernetes/monitoring/             # 3. Prometheus + Grafana + KSM + Node Exporter
kubectl apply -f /opt/kubernetes/nginx/                  # 4. Nginx Deployment + Service
kubectl apply -f https://...metrics-server...            # 5. Auto-deploy metrics-server
kubectl apply -f /opt/kubernetes/autoscaling/            # 6. HPA for nginx
kubectl apply -f /opt/kubernetes/security/               # 7. Network Policies + RBAC
kubectl apply -f /opt/kubernetes/falco/                  # 8. Falco DaemonSet (if enabled)
```

---

## 4. Ansible & Automation Q&A

### Q: What is Ansible and why did you choose it?
**A**: Ansible is an **agentless automation tool** that uses SSH and YAML playbooks.

| Why Ansible | Why Not Terraform |
|---|---|
| Agentless (SSH only) | Terraform needs state files |
| YAML-based (easy to learn) | HCL is a separate language |
| Designed for server config | Designed for cloud provisioning |
| Idempotent (safe to re-run) | State management complexity |

### Q: Explain your Ansible role structure.
**A**: 4 roles, run in order by `site.yml`:

| Role | Purpose | Key Tasks |
|---|---|---|
| `common` | Prepare ALL nodes | Disable swap, install containerd + K8s packages, load kernel modules |
| `k8s_master` | Initialize cluster | `kubeadm init`, install Flannel, setup kubectl, generate join token, etcd backup cron |
| `k8s_worker` | Join workers | Copy join command, `kubeadm join`, wait for Ready |
| `security` | Harden nodes | UFW firewall, SSH hardening, CIS benchmarks (file perms, kernel params) |

### Q: What is idempotency?
**A**: Running a playbook **multiple times produces the same result**. Example:
```yaml
- name: Install containerd
  apt:
    name: containerd
    state: present  # Only installs if not already present
```
Running this 10 times won't reinstall containerd each time.

### Q: How does the worker join the cluster?
**A**:
1. Master generates join token: `kubeadm token create --print-join-command`
2. Ansible copies the command to workers
3. Worker executes: `kubeadm join 192.168.144.130:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>`
4. Worker's kubelet registers with the API server → node becomes `Ready`

### Q: Key Ansible commands?

| Command | Purpose |
|---|---|
| `ansible-playbook -i inventory/hosts.ini site.yml` | **Deploy everything** |
| `ansible -i inventory/hosts.ini all -m ping` | Test connectivity to all servers |
| `ansible-playbook site.yml --check` | Dry run (no changes) |
| `ansible-playbook site.yml -vvv` | Verbose output |
| `ansible-playbook site.yml --tags common` | Run only the common role |

---

## 5. Kubernetes Core Q&A

### Q: What is Kubernetes?
**A**: An open-source **container orchestration platform** that automates deployment, scaling, self-healing, and load balancing of containerized applications.

### Q: Explain the architecture in your project.
**A**: **Control Plane** (master) + **Data Plane** (worker):

| Component | Node | Port | Purpose |
|---|---|---|---|
| API Server | Master | 6443 | Entry point for all cluster operations |
| etcd | Master | 2379 | Stores ALL cluster state (the database) |
| Scheduler | Master | — | Assigns pods to nodes |
| Controller Manager | Master | — | Ensures actual state = desired state |
| kubelet | Worker | 10250 | Manages pod lifecycle on each node |
| kube-proxy | Worker | — | Network routing (iptables rules) |
| containerd | Worker | — | Container runtime (runs containers) |

### Q: Pod vs Deployment vs Service?

| Concept | What It Is | In My Project |
|---|---|---|
| **Pod** | Smallest unit — contains container(s) | Nginx runs in a pod |
| **Deployment** | Manages pod replicas + rolling updates | `nginx` deployment with 2 replicas |
| **Service** | Stable network endpoint for pods | NodePort service exposes nginx on :30080 |

### Q: What is a namespace?
**A**: Virtual clusters within a cluster for isolation.

| Namespace | What's In It |
|---|---|
| `default` | Nginx application, HPA |
| `monitoring` | Prometheus, Grafana, Node Exporter, KSM |
| `kube-system` | Core K8s components, Flannel, metrics-server |
| `falco` | Falco runtime security |

### Q: Why containerd instead of Docker?
**A**: Kubernetes **removed Docker** as container runtime in v1.24. containerd is Docker's backend engine without the extras — lighter (~50MB), CRI-compliant, industry standard.

### Q: Why did you remove the NoSchedule taint from master?
**A**: By default, master nodes won't run application pods. In our **2-node, 8GB setup**, we need both nodes to run workloads:
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

### Q: What is the `kubeadm init` command?
```bash
kubeadm init \
  --apiserver-advertise-address=192.168.144.130 \   # Master IP
  --pod-network-cidr=10.244.0.0/16 \                # Must match Flannel
  --service-cidr=10.96.0.0/12 \                     # Service IP range
  --cri-socket=unix:///run/containerd/containerd.sock  # Use containerd
```

### Q: Why Flannel CNI?

| Feature | Flannel | Calico |
|---|---|---|
| RAM usage | ~50 MB | ~100-200 MB |
| Complexity | Simple VXLAN overlay | Full BGP networking |
| Network Policies | No (K8s handles them) | Built-in |
| **Best for** | **Small clusters, learning** | Production, >10 nodes |

We chose Flannel for **8GB RAM optimization**.

---

## 6. Storage Q&A

### Q: What are PV and PVC?

| Concept | Role | Analogy |
|---|---|---|
| **PersistentVolume (PV)** | Actual storage provisioned by admin | A hard disk |
| **PersistentVolumeClaim (PVC)** | Request for storage by a pod | A purchase order |
| **StorageClass** | Groups PVs by type | "NFS type" or "SSD type" |

### Q: How does NFS storage work?
**A**: `NFS Server` → `PV` (points to NFS path) → `PVC` (requests storage) → `Pod` (mounts volume)

| PV | Size | PVC | Used By | NFS Path |
|---|---|---|---|---|
| `nfs-prometheus-pv` | 5Gi | `prometheus-pvc` | Prometheus | `/srv/nfs/kubernetes/prometheus` |
| `nfs-grafana-pv` | 2Gi | `grafana-pvc` | Grafana | `/srv/nfs/kubernetes/grafana` |
| `nfs-nginx-pv` | 1Gi | `nginx-pvc` | Nginx web content | `/srv/nfs/kubernetes/nginx` |
| `nfs-kubernetes-pv` | 10Gi | `nfs-pvc` | General data | `/srv/nfs/kubernetes` |

### Q: Why NFS?

| Option | Pros | Cons | Why Chosen/Not |
|---|---|---|---|
| **NFS** | Simple, RWX, external to cluster | Single point of failure | ✅ Perfect for 2-node lab |
| hostPath | Simplest | No sharing between nodes | ❌ Data lost if pod moves |
| Longhorn | Cloud-native, replicated | ~500MB per node | ❌ Too heavy |
| Ceph | Enterprise, distributed | Very complex | ❌ Overkill |

### Q: What is `ReadWriteMany` (RWX)?
**A**: Multiple pods on multiple nodes can **read and write** simultaneously. Essential for NFS where Prometheus and Grafana need shared access.

### Q: What if PVC is stuck in Pending?
**A**: Common causes:
1. No matching PV — check labels and storage size
2. StorageClass mismatch — verify `storageClassName` matches
3. NFS not accessible — test with `showmount -e <nfs-server>`

```bash
kubectl describe pvc <pvc-name>  # Shows WHY it's pending
```

---

## 7. Monitoring Q&A

### Q: What is Prometheus and how does it work?
**A**: **Pull-based** time-series monitoring. Every 30 seconds it:
1. **Scrapes** HTTP `/metrics` endpoints from targets
2. **Stores** data in a time-series database
3. **Queries** via PromQL
4. **Triggers alerts** based on rules

### Q: What metrics do you collect?

| Source | Port | Metrics |
|---|---|---|
| Node Exporter | 9100 | CPU, RAM, disk, network (hardware) |
| Kube-State-Metrics | 8080 | Pod status, deployment replicas, node conditions |
| kubelet | via API | Container CPU/memory |
| API Server | 6443 | Request latency, error rate |
| Falco | 8765 | Security event counts |

### Q: What is Kube-State-Metrics (KSM)?
**A**: Generates metrics about **Kubernetes object states** (not resource usage).

| Without KSM | With KSM |
|---|---|
| No pod count | `kube_pod_status_phase{phase="Running"}` |
| No deployment info | `kube_deployment_status_replicas` |
| Grafana shows "No Data" | Full K8s visibility |

### Q: How does Grafana integrate?
**A**: Grafana uses Prometheus as a **datasource** and queries it via PromQL:
```yaml
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
```
4 pre-built dashboards: Cluster Overview, Node Metrics, Pod Resources, Falco Security.

### Q: Prometheus configuration?

| Setting | Value | Why |
|---|---|---|
| Scrape interval | 30s | Save resources (vs default 15s) |
| Retention time | 3 days | Limit disk usage |
| Retention size | 1GB | Cap storage |
| Memory limit | 512Mi | 8GB RAM optimization |
| Storage | `prometheus-pvc` (NFS 5Gi) | Data persists across restarts |

### Q: What alert rules do you have?

| Alert | Condition | Severity |
|---|---|---|
| NodeDown | Node unreachable | 🔴 Critical |
| HighCPUUsage | CPU > 80% for 5min | 🟡 Warning |
| HighMemoryUsage | Memory > 85% for 5min | 🟡 Warning |
| DiskSpaceLow | Disk < 15% | 🟡 Warning |
| PodCrashLooping | Restarts > 0.5/min for 5min | 🟡 Warning |
| DeploymentReplicasMismatch | Actual ≠ Desired for 10min | 🟡 Warning |
| NginxDown | Nginx unreachable for 2min | 🔴 Critical |

---

## 8. Security Q&A

### Q: Explain your multi-layer security approach.

```
Layer 1: HOST SECURITY (Ansible security role)
├── UFW Firewall (deny by default, whitelist ports)
├── SSH hardening (key-only, no root, no password auth)
├── Kernel hardening (ASLR, rp_filter, no source routing)
└── CIS Benchmarks (file perms 0600, etcd dir 0700)

Layer 2: KUBERNETES SECURITY
├── Pod Security Standards (baseline enforce, restricted warn)
├── ServiceAccount RBAC (developer, deployer, prometheus, KSM, falco)
└── Secrets management (Grafana credentials in K8s Secret)

Layer 3: NETWORK SECURITY
├── default-deny-ingress (block all incoming)
├── default-deny-egress (block all outgoing)
├── allow-dns-egress (port 53 — service discovery)
├── allow-nginx-ingress (port 8080)
├── allow-nginx-egress (port 2049 — NFS)
└── allow-prometheus-scrape (ports 8080, 9100)

Layer 4: RUNTIME SECURITY
├── Falco DaemonSet (syscall monitoring via eBPF)
└── Container SecurityContext (non-root, seccomp, drop capabilities)
```

### Q: What is RBAC?
**A**: Role-Based Access Control — defines WHO can do WHAT.

**Our ServiceAccount RBAC:**

| ServiceAccount | Role | What They Can Do |
|---|---|---|
| `developer` | `developer-role` | Read pods, logs, services, deployments, events |
| *(any)* | `cluster-viewer` | Read-only cluster-wide access (nodes, namespaces, pods) |
| *(any)* | `deployer-role` | Create/update deployments, read pods/services |
| `prometheus` | `prometheus` | Read nodes, services, endpoints, /metrics |
| `kube-state-metrics` | `kube-state-metrics` | List/watch all K8s objects |
| `falco` | `falco` | Read nodes, pods, deployments |

**Verify:**
```bash
kubectl auth can-i list pods --as=system:serviceaccount:default:developer
# yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:developer
# no ← Least privilege!
```

### Q: What are Pod Security Standards (PSS)?
**A**: PSS replaced deprecated PodSecurityPolicy in K8s 1.25.

| Level | Restrictions |
|---|---|
| **Privileged** | No restrictions (for system pods) |
| **Baseline** | Blocks: privileged, hostNetwork, hostPath, SYS_ADMIN |
| **Restricted** | Additionally requires: non-root, drop ALL capabilities |

**We use**: `enforce=baseline` + `warn=restricted`
```bash
kubectl label namespace default \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
```

### Q: Explain Network Policies in your project.

| # | Policy | Direction | What It Does |
|---|---|---|---|
| 1 | `default-deny-ingress` | Ingress | Blocks ALL incoming to default ns |
| 2 | `default-deny-egress` | Egress | Blocks ALL outgoing from default ns |
| 3 | `allow-dns-egress` | Egress | Allows DNS (port 53) for service discovery |
| 4 | `allow-nginx-ingress` | Ingress | Allows traffic to nginx on port 8080 |
| 5 | `allow-nginx-egress` | Egress | Allows nginx to access NFS (port 2049) |
| 6 | `allow-prometheus-scrape` | Ingress | Allows monitoring ns to scrape (ports 8080, 9100) |

**Effect**: Zero Trust — block everything, then whitelist specific traffic.

### Q: What is Falco?
**A**: Runtime security tool that monitors **system calls** using eBPF.

| Rule | Priority | Triggers When |
|---|---|---|
| Shell Spawned in Container | ⚠️ WARNING | bash/sh/zsh execution inside container |
| Sensitive File Access | 🔴 CRITICAL | Reading /etc/shadow, admin.conf |
| Kubectl Exec Detected | 📝 NOTICE | Interactive `kubectl exec -it` |

**Test it:**
```bash
kubectl exec -it <nginx-pod> -- /bin/sh    # Triggers Falco alert
kubectl logs -n falco -l app=falco         # See the alert
```

### Q: How do you handle Grafana credentials?
**A**: Stored in a **Kubernetes Secret**, not hardcoded:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-credentials
  namespace: monitoring
stringData:
  admin-user: admin
  admin-password: K8sGrafana@2024!
```
Grafana references it via `secretKeyRef` in environment variables.

### Q: What CIS benchmarks do you implement?
| Control | What It Does |
|---|---|
| CIS 1.1 | Secure file permissions on manifests (0600) |
| CIS 1.1.12 | etcd data directory permissions (0700) |
| CIS 4.2.1 | Disable anonymous kubelet auth |
| CIS 4.2.4 | Disable kubelet read-only port |
| CIS 5.2 | Pod Security Standards enforced |
| CIS 5.3.2 | Network Policies in place |

---

## 9. Autoscaling Q&A

### Q: What is HPA and how does it work?
**A**: Horizontal Pod Autoscaler automatically adjusts the number of pod replicas.

```
metrics-server (collects CPU/memory from kubelets)
        │
        ▼
HPA checks every 15s: "Is nginx CPU > 70%?"
        │                    │
        ▼ YES                ▼ NO
  Scale UP (2→3 pods)    Keep current
  (max: 5 pods)
```

**Configuration:**
```yaml
scaleTargetRef: nginx deployment
minReplicas: 2
maxReplicas: 5
metrics:
  - cpu: 70% average utilization
  - memory: 80% average utilization
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
```

### Q: What is metrics-server?
**A**: Lightweight component that collects **real-time CPU/memory** from kubelets. HPA needs this to make scaling decisions. Auto-deployed by Ansible with `--kubelet-insecure-tls` (required for kubeadm clusters).

### Q: How do you scale manually?
```bash
kubectl scale deployment nginx --replicas=5     # Manual scale
kubectl get hpa                                  # Check HPA status
kubectl top pods                                 # See CPU/memory usage
```

### Q: What is VPA?
**A**: Vertical Pod Autoscaler — adjusts CPU/memory **requests and limits** of existing pods (right-sizing). Not yet implemented but planned as a future enhancement.

---

## 10. Self-Healing & Reliability Q&A

### Q: How does Kubernetes achieve self-healing?

| Mechanism | What It Does |
|---|---|
| Deployment controller | Maintains desired replica count |
| Liveness probe | Restarts unhealthy containers |
| Readiness probe | Removes unready pods from service endpoints |
| Node controller | Reschedules pods from failed nodes |

### Q: Explain liveness vs readiness probes.

| Probe | Purpose | On Failure |
|---|---|---|
| **Liveness** | "Is the container alive?" | Container is **restarted** |
| **Readiness** | "Can it serve traffic?" | Pod is **removed from Service endpoints** |

**Our nginx probes:**
```yaml
livenessProbe:
  httpGet: { path: /, port: 8080 }
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3       # 3 failures → restart

readinessProbe:
  httpGet: { path: /, port: 8080 }
  initialDelaySeconds: 5
  periodSeconds: 3
```

### Q: How do you demonstrate self-healing?
```bash
kubectl get pods -l app=nginx              # Show 2 running
kubectl delete pod nginx-xxxxx             # Delete one
kubectl get pods -l app=nginx -w           # Watch auto-recreation!
# New pod appears within seconds
```

### Q: What is your rolling update strategy?
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1           # 1 extra pod during update
    maxUnavailable: 0     # Never go below desired count
```
**Zero-downtime**: New pod → readiness check → add to service → remove old pod.

### Q: What's your etcd backup strategy?
- **Automated**: Cron runs every hour
- **Local**: 24 hourly snapshots in `/backup/etcd/`
- **Remote**: 7 daily backups on NFS server
- **Restore**: `etcdctl snapshot restore` → restart API server → verify

```bash
etcdctl snapshot save /backup/etcd/snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

## 11. Troubleshooting Q&A

### Q: How do you troubleshoot a CrashLoopBackOff pod?
```bash
kubectl describe pod <pod-name>        # Check events
kubectl logs <pod-name>                # Current logs
kubectl logs <pod-name> --previous     # Previous crash logs
kubectl get events --sort-by=.lastTimestamp
```
**Common causes**: Missing ConfigMaps/Secrets, resource limits too low, application crash, permission issues.

### Q: Common issues and solutions?

| Issue | Cause | Solution |
|---|---|---|
| Pods stuck in Pending | No schedulable nodes | Remove master taint or check resources |
| PVC stuck in Pending | No matching PV | Check PV labels, StorageClass |
| Node NotReady | CNI not running | Check Flannel pods, network |
| ImagePullBackOff | Can't pull image | Check internet, registry, image name |
| CrashLoopBackOff | Container crashing | `kubectl logs` for details |

### Q: How do you check cluster health?
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get events --sort-by='.lastTimestamp'
./scripts/diagnose-services.sh   # 14-point health check
```

---

## 12. Scenario-Based Q&A

### Q: If the master node goes down, what happens?

| Component | Impact | Recovery |
|---|---|---|
| API Server | No new deployments, no kubectl | Restart master, API recovers from etcd |
| Scheduler | No new pods scheduled | Catches up after restart |
| Controller Manager | No self-healing | Catches up after restart |
| etcd | Cluster state unavailable | Restore from backup if corrupted |
| **Worker Pods** | **Continue running** | Reconnect when master is back |

### Q: Someone deleted a namespace. How to recover?
```bash
# Option 1: Restore from etcd backup
etcdctl snapshot restore /backup/etcd/latest.db --data-dir=/var/lib/etcd-restored

# Option 2: Re-apply from git
ansible-playbook -i inventory/hosts.ini site.yml --tags deploy_services
```

### Q: How would you scale for production?

| Current | Production |
|---|---|
| 2 nodes | 3+ masters (HA), 3+ workers |
| NodePort | Ingress Controller + LoadBalancer |
| 8GB RAM | 16GB+ per node |
| Flannel | Calico (built-in Network Policies) |
| NFS (single) | NFS HA or cloud storage (EBS, PD) |

### Q: How to implement zero-downtime deployments?
**A**: Already implemented! `maxSurge: 1` + `maxUnavailable: 0` + readiness probes = new pod starts → passes health check → joins service → old pod removed.

---

## 13. Story Mode

### "Walk me through how you built this from scratch"

**Phase 1 — Blueprint**: Chose multi-node cluster on Ubuntu 22.04, kubeadm for vendor neutrality, separate NFS server for data persistence.

**Phase 2 — Foundation**: Wrote Ansible playbooks with roles (`common`, `security`, `k8s_master`, `k8s_worker`). Ran `ansible-playbook site.yml` — 15 minutes from empty VMs to running cluster.

**Phase 3 — Security**: Applied Defense-in-Depth: UFW firewalls, Falco runtime monitoring, Pod Security Standards (Baseline enforce + Restricted warn).

**Phase 4 — Observability**: Deployed Prometheus + Grafana with pre-built dashboards. Node Exporter and KSM for complete metrics coverage.

**Phase 5 — Safety Net**: Automated etcd backup script — hourly snapshots to NFS. Tested restore procedure.

### "If a user accesses your application, what happens step-by-step?"

1. **DNS** → resolves to node IP
2. **Firewall (UFW)** → allows traffic on port 30080
3. **kube-proxy** → routes to Service IP via iptables
4. **Network Policy** → checks `allow-nginx-ingress` — allows on port 8080
5. **Readiness probe** verified this pod is ready to serve
6. **Nginx container** processes request, reads from NFS-backed PVC
7. **Response** returned to user
8. **Meanwhile**: Prometheus scrapes metrics, Grafana visualizes, Falco monitors for threats

---

## 14. Challenges Faced & Solutions

### Challenge 1: kubeadm init Failures
**Problem**: API server not responding.
**Cause**: Swap not fully disabled in `/etc/fstab`.
**Fix**: Both `swapoff -a` AND comment out fstab swap entry.
**Learning**: Always handle both runtime AND persistent configuration.

### Challenge 2: Flannel Stuck in Init:0/1
**Problem**: Flannel pods not starting.
**Cause**: `net.bridge.bridge-nf-call-iptables` not set before Flannel.
**Fix**: Load `br_netfilter` kernel module BEFORE applying sysctl.
**Learning**: Order of operations matters in automation.

### Challenge 3: PVCs Stuck in Pending
**Problem**: PVCs not binding to PVs.
**Cause**: PV labels didn't match PVC selector.
**Fix**: Ensure PV `labels.app` matches PVC `selector.matchLabels.app`.
**Learning**: Static PV provisioning needs careful label matching.

### Challenge 4: 8GB RAM Exhaustion
**Problem**: Out of memory after deploying monitoring.
**Cause**: Default Prometheus settings too aggressive.
**Fix**: Reduced retention (3d), capped storage (1GB), limited memory (512Mi).
**Learning**: Consider resource constraints from the start.

### Challenge 5: Grafana "No Data" for K8s Metrics
**Problem**: CPU/Memory dashboards worked, but pod metrics showed "No Data".
**Cause**: Kube-State-Metrics wasn't deployed.
**Fix**: Added KSM deployment with proper ClusterRole RBAC.
**Learning**: Node Exporter ≠ Kubernetes metrics. KSM is essential.

### Challenge 6: Worker Join Token Expired
**Problem**: Worker join failed after 24 hours.
**Cause**: Bootstrap tokens expire by default.
**Fix**: Always generate fresh token: `kubeadm token create --print-join-command`
**Learning**: Use fresh tokens in automation, don't store old ones.

### Challenge 7: CIS 4.2.6 Breaking kubelet
**Problem**: kubelet wouldn't start after `protectKernelDefaults: true`.
**Cause**: Required kernel parameters not all set.
**Fix**: Disabled this control with documentation of the tradeoff.
**Learning**: Security best practices may conflict with specific environments.

---

## 15. Team & Collaboration

### Q: Was this individual or team?
**A**: **Team project with 5 members**, divided by expertise:

| Member | Role | Responsibilities |
|---|---|---|
| **Me** | DevOps Lead | Ansible playbooks, K8s manifests, integration, coordination |
| Member 2 | Infrastructure | VM setup, NFS server, network configuration |
| Member 3 | Monitoring | Prometheus config, Grafana dashboards, alert rules |
| Member 4 | Security | UFW, CIS benchmarks, Falco setup |
| Member 5 | Documentation | Setup guides, testing, diagnostic scripts |

### Q: How did the team collaborate?
**A**: Agile approach — Monday sprint planning, daily standups, Wednesday integration testing, Friday demos. Git feature branches → pull requests → code review → merge.

### Q: How did you handle disagreements?
**A**: Data-driven decisions. Example: Flannel vs Calico — tested both, Calico used 100MB more per node. Decision: Flannel + separate Network Policy manifests.

---

## 16. HR & Behavioral Questions

### Q: Why did you choose this project?
**A**: Wanted hands-on experience with Kubernetes administration (not just using it), Infrastructure as Code (Ansible), and DevOps practices (monitoring, security, backup).

### Q: What did you learn?

| Area | Learning |
|---|---|
| Kubernetes | Control plane, networking, storage, security, autoscaling |
| Ansible | Roles, idempotency, handlers, variables |
| Monitoring | Time-series DBs, PromQL, Grafana dashboards |
| Security | CIS benchmarks, PSS, runtime security |
| Troubleshooting | Pod debugging, log analysis, network issues |

### Q: How would you improve this project?
**Already implemented:**
- ✅ HPA autoscaling with auto-deployed metrics-server
- ✅ K8s Secrets for Grafana credentials
- ✅ Pinned image tags (no `:latest`)

**Future enhancements:**
1. High Availability — multiple master nodes with HAProxy
2. GitOps — ArgoCD for declarative deployments
3. Log Management — Loki for log aggregation
4. Ingress Controller — replace NodePorts
5. External Secrets — HashiCorp Vault
6. VPA — right-size container resources automatically

---

## 17. General IT & Security Concepts

### Networking Basics

**DNS Resolution**: Browser cache → OS cache → ISP Resolver → Root → TLD → Authoritative → IP returned.

**TCP vs UDP**: TCP = reliable, 3-way handshake (HTTP, SSH). UDP = fast, no handshake (DNS, streaming).

**OSI Model Security**: Physical (locks) → Data Link (MAC filtering) → Network (firewalls) → Transport (TLS/SSL) → Application (WAF).

### Security Concepts

**CSRF**: Attacker tricks logged-in user into performing actions. Prevention: Anti-CSRF tokens.

**SQL Injection**: `' OR 1=1 --` in login field bypasses auth. Prevention: Parameterized queries.

**WAF**: Layer 7 firewall that inspects HTTP for SQLi, XSS attacks.

**IDS vs IPS vs Firewall**:
- Firewall: Gatekeeper (allow/block by IP/port)
- IDS: Alarm (detects, alerts — passive)
- IPS: Guard (detects, blocks — active)
- Falco = host-based IDS for containers

**Symmetric vs Asymmetric Encryption**:
- Symmetric (AES): Same key for encrypt/decrypt — fast
- Asymmetric (RSA): Public encrypts, Private decrypts — secure

**Zero Trust**: "Never Trust, Always Verify" — even inside the network. Our Network Policies implement this.

**Risk = Threat × Vulnerability**: Vulnerability (open door) + Threat (burglar) = Risk (probability of loss).

### Linux Commands

| Command | Purpose |
|---|---|
| `ls -lah` | List all files with permissions |
| `ps aux` | Show running processes |
| `netstat -tuln` | Check listening ports |
| `chmod 600 file` | Owner read/write only |
| `grep -r "pattern" /path` | Search recursively |
| `top` / `htop` | Real-time resource monitoring |
| `ufw status` | Firewall rules |
| `systemctl status kubelet` | Service status |

---

## 18. Quick Reference Card

### Service Access

| Service | URL | Credentials | Port |
|---|---|---|---|
| **Prometheus** | `http://<master-ip>:30090` | None | 30090→9090 |
| **Grafana** | `http://<master-ip>:30300` | `admin` / `K8sGrafana@2024!` | 30300→3000 |
| **Nginx** | `http://<master-ip>:30080` | None | 30080→8080 |

### Essential Commands
```bash
# Deploy cluster
ansible-playbook -i inventory/hosts.ini site.yml

# Check health
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl get hpa

# Troubleshoot
kubectl describe pod <name>
kubectl logs <pod>
./scripts/diagnose-services.sh

# Scale
kubectl scale deployment nginx --replicas=5

# Security check
kubectl get networkpolicy
kubectl auth can-i list pods --as=system:serviceaccount:default:developer
```

### Key Variables (`all.yml`)

| Variable | Value |
|---|---|
| `kubernetes_version` | 1.29 |
| `cni_plugin` | flannel |
| `pss_level` | baseline |
| `enable_falco` | true |
| `grafana_admin_password` | K8sGrafana@2024! |
| `prometheus_memory_limit` | 512Mi |

### RAM Budget (8GB total)

| Component | Memory |
|---|---|
| K8s system (kubelet, API, etcd) | ~1.5 GB |
| Flannel CNI (×2) | 100 MB |
| Prometheus | 512 MB |
| Grafana | 256 MB |
| Nginx (×2) | 128 MB |
| Falco (×2) | 512 MB |
| Node Exporter + KSM | ~150 MB |
| **Buffer** | ~500 MB |

### Key Design Decisions

| Decision | Reason |
|---|---|
| **Ansible (not Terraform)** | Configuring VMs, not provisioning cloud infra |
| **Flannel (not Calico)** | ~50MB vs ~200MB RAM per node |
| **NFS (not Longhorn)** | RWX support, simple, external to cluster |
| **Baseline PSS (not Restricted)** | Balances security with compatibility |
| **3-day Prometheus retention** | Prevents disk exhaustion on NFS |
| **K8s Secrets for Grafana** | No hardcoded credentials in manifests |
| **Pinned image tags** | Reproducible deployments |
| **ServiceAccount RBAC** | More K8s-native than User-based |

---

> 📅 *Document updated: March 2026*
> 📁 *Project: Kubernetes Cluster Setup with Ansible Automation (CDAC)*
> 👤 *Role: DevOps Engineer / Team Lead*

# 🎤 Interview Pitch — Kubernetes Cluster Automation Project

> **How to use this:**
> - **Section 1** → Say this the moment they ask *"What is your project?"* — plain English, no jargon
> - **Section 2** → Say this when they ask *"Walk me through it technically"*
> - **Section 3** → Pull from this when they ask specific follow-up questions

---

## 🗣️ Section 1 — "What Is Your Project?" (Speak This First)

> **Your natural style — casual, direct, confident. Just say it like this.**

---

*"So basically, what I built is — I automated the complete setup of a Kubernetes cluster using **Ansible** and **kubeadm** on Ubuntu Linux.*

*The problem I was solving: setting up Kubernetes manually is a very long and error-prone process. You're running 50-plus commands across multiple servers, it takes 2 to 3 hours, and one wrong step can break the whole thing. And if you need to do it again for a different environment, you start from zero.*

*So I wrote automation — using a tool called **Ansible** — that does all of this in one command. You just give it the IP addresses of your servers, and in about **15 minutes**, you have a fully working, production-ready Kubernetes cluster. No manual steps, nothing to forget.*

*Now let me tell you what the cluster actually does:*

*The cluster has two parts — a **master node** and a **worker node**. The master is the brain — it's the control plane that handles scheduling, manages which pod runs where, and stores the entire cluster state in a database called **etcd**. The worker is where the actual applications run.*

*On top of the basic cluster, I automated a lot more things:*

*For **storage** — I connected an external **NFS server**, and set up PersistentVolumes and PVCs for it. So if a pod crashes and restarts, the data is still there on the NFS server. Nothing is lost.*

*For **monitoring** — I deployed **Prometheus** and **Grafana** automatically. Prometheus collects metrics from the nodes every 30 seconds — CPU, RAM, disk, pod health — everything. Grafana shows all of it on pre-built dashboards. I also configured alert rules, so if CPU goes above 80% or a pod keeps crashing, it raises an alert.*

*To **test that the cluster works**, I deployed a demo **Nginx web server**. It runs with 2 replicas, saves data to the NFS server, and if a pod goes down, Kubernetes automatically restarts it. So the self-healing works.*

*For **security**, I layered it in 4 ways — firewall rules and SSH hardening at the server level, Pod Security Standards and RBAC at the Kubernetes level, Network Policies for zero-trust traffic control, and Falco for runtime threat detection inside containers.*

*And for **disaster recovery** — I set up automated hourly backups of etcd. If the master node ever goes down, existing applications on the worker keep running. To restore the cluster fully, I restore from the etcd backup snapshot."*

---

## 🔧 Section 2 — Technical Deep Dive (When They Want More Detail)

> Use this when they say *"tell me more"* or *"walk me through the technical side."*

---

*"The automation is built with **Ansible** and structured as a single playbook — `site.yml` — which has **4 plays** that run in sequence:*

**Play 1 — runs on all nodes (master + worker):**
*It configures the operating system — disables swap, loads the kernel modules that Kubernetes needs like `overlay` and `br_netfilter`, sets the sysctl networking parameters, installs the **containerd** container runtime, and installs Kubernetes v1.35 packages. It also applies full security hardening — UFW firewall, SSH hardening, and CIS Kubernetes Benchmark controls.*

**Play 2 — runs only on the master node:**
*It initializes the Kubernetes control plane using `kubeadm init`, installs **Flannel CNI** for pod networking between nodes over VXLAN, applies Pod Security Standards at `baseline` enforcement on the default namespace, generates a join token for the worker, and sets up an **automated hourly etcd backup cron job** to the NFS server.*

**Play 3 — runs only on the worker node:**
*It takes the join token from the master, runs `kubeadm join`, and polls until the node shows `Ready` status.*

**Play 4 — back on the master, deploys all services:**
*In order: NFS PersistentVolumes and PVCs for storage, the Prometheus and Grafana monitoring stack with pre-built dashboards, the Nginx application, metrics-server and HPA for autoscaling, Network Policies and RBAC for security, and finally Falco for runtime threat detection.*

*Now let me explain the key components in detail:*

**Storage:**
*I configured an external NFS server with 4 PersistentVolumes — 10Gi for general data, 5Gi for Prometheus, 2Gi for Grafana, and 1Gi for Nginx. Pods mount these over the network using PVCs. The etcd backup script runs every hour via cron — it saves snapshots locally for 24 hours, and copies them to the NFS server where they're kept for 7 days.*

**Monitoring:**
*Prometheus scrapes 5 sources every 30 seconds — **Node Exporter** for hardware metrics like CPU and RAM, **Kube-State-Metrics** for Kubernetes object state like deployment replicas, **Kubelet** for container-level metrics, the **API Server** for request latency, and **Falco** for security event counts. I configured alert rules that fire for — NodeDown, HighCPU above 80%, HighMemory above 85%, DiskSpaceLow below 15%, DiskSpaceCritical below 5%, PodCrashLooping, KubernetesNodeNotReady, NginxPodsUnavailable, and more. Grafana has pre-built dashboards provisioned automatically.*

**Security — 4 layers:**
- *Host layer: UFW firewall with deny-by-default, SSH hardened to key-only with no root login, kernel hardening via sysctl, CIS Kubernetes Benchmarks. The security Ansible role has 34 tasks.*
- *Cluster layer: Pod Security Standards at baseline — blocks containers running as root, using hostNetwork, hostPath, or dangerous capabilities. RBAC with 3 ServiceAccount roles — `viewer` for read-only cluster access, `developer` for pod logs and events in the default namespace, and `deployer` for managing deployments — designed for CI/CD pipelines.*
- *Network layer: A `default-deny` NetworkPolicy blocks all ingress and egress in the default namespace. Explicit allow rules open only what's needed — port 8080 for Nginx HTTP, port 53 for DNS, port 2049 for NFS, and allow from the monitoring namespace for Prometheus scraping.*
- *Runtime layer: Falco runs as a DaemonSet on every node, uses eBPF to watch Linux system calls in real time, and alerts on suspicious behaviour — like a shell spawning inside a container, sensitive file reads like `/etc/shadow`, or unexpected kubectl exec calls.*

**Self-healing and Autoscaling:**
*Nginx has liveness and readiness probes — if it fails 3 consecutive health checks, Kubernetes kills and restarts the pod automatically. I also deployed an HPA backed by metrics-server, so Nginx auto-scales based on CPU and memory load.*

**Operational Scripts — I wrote 3:**
- *`etcd-backup.sh` — automated etcd snapshots with local 24h retention and NFS 7-day retention*
- *`generate-kubeconfig.sh` — creates a time-limited kubeconfig file for any RBAC ServiceAccount using the Kubernetes TokenRequest API. Token expires in 24 hours.*
- *`diagnose-services.sh` — a 14-point cluster health check covering: cluster connectivity, node status, namespaces, PersistentVolume binding, pod health, deployment status, service endpoints, NodePort accessibility, firewall status, NFS connectivity — all in one run.*

*Everything is Infrastructure-as-Code — fully repeatable, version-controlled, and tuned to run inside an 8GB RAM, 2-node VMware lab environment."*

---

## ❓ Section 3 — Follow-Up Q&A

---

### 1. "Why Ansible and not Terraform?"

*"Ansible is a configuration management tool — it connects over SSH and configures the OS, installs packages, and manages services. Terraform is for infrastructure provisioning — spinning up VMs on AWS or Azure. My VMs were already provisioned on VMware, so I needed Ansible to configure them. Ansible is also agentless — I didn't need to install anything on the target servers first."*

---

### 2. "Why containerd and not Docker?"

*"Kubernetes deprecated Docker as a runtime starting in v1.24, because Docker doesn't natively implement the CRI — Container Runtime Interface — that Kubernetes expects. containerd does. It's also lighter, around 50MB, and doesn't carry the extra overhead of Docker's CLI and build daemon."*

---

### 3. "What is the master node's role exactly?"

*"The master node is the control plane — it runs the API Server, Scheduler, Controller Manager, and etcd. It decides which pod runs on which node, watches for failures, and maintains the desired state of the cluster. It doesn't run application workloads by default — in my 8GB lab setup I removed the NoSchedule taint to allow that, but the master's main job is management, not running apps."*

---

### 4. "What happens if the master node goes down?"

*"Good question — and I want to be honest here. This is a single-master setup, so the master is a single point of failure for the control plane. If the master goes down, the existing pods on the worker node keep running and serving traffic — Kubernetes doesn't kill them just because the master is gone. But no new scheduling, no new deployments, no API calls can happen until the master is back. My disaster recovery strategy is the hourly etcd backups to NFS — I can restore the entire cluster state from those snapshots. In a production environment, you'd extend this to 3 master nodes with an external etcd cluster for high availability."*

---

### 5. "How does Zero-Trust networking work in your setup?"

*"I wrote a NetworkPolicy that applies `default-deny` for both ingress and egress traffic on the default namespace. So by default, every pod is completely isolated — no traffic in, no traffic out. Then I layered explicit allow rules on top. Nginx gets port 8080 open for HTTP, port 53 for DNS, port 2049 for NFS access. There's also a separate policy that allows the monitoring namespace to scrape metrics from the default namespace. If I haven't written an allow rule for a specific flow, it simply doesn't happen."*

---

### 6. "What does Falco do exactly?"

*"Falco is a runtime security tool. It runs as a DaemonSet on every node and uses eBPF to hook into the Linux kernel and watch system calls in real time — not container logs, actual kernel-level calls. If a container spawns a bash shell, reads `/etc/shadow`, runs an unexpected binary, or makes network connections it shouldn't, Falco generates an alert immediately. It also exposes its own metrics endpoint at port 8765 which Prometheus scrapes, so I can see security events on the Grafana Falco dashboard."*

---

### 7. "How does storage survive a pod crash?"

*"Pods don't store data locally. They use PersistentVolumeClaims backed by an external NFS server. The NFS directory is mounted over the network — it's completely outside the cluster. If a pod crashes and a new one starts on any node, it remounts the same NFS PVC and reads the same data. Nothing is lost. On top of that, the etcd backup runs every hour — local snapshots kept for 24 hours, NFS copies kept for 7 days. So even if the entire cluster is destroyed, I can restore the cluster state from those snapshots."*

---

### 8. "Explain your RBAC setup."

*"I created 3 ServiceAccount-based roles. The `viewer` SA is bound to a ClusterRole — it has read-only access across the entire cluster, can list nodes, namespaces, pods, and deployments, but cannot change anything. The `developer` SA has a namespace-scoped Role in the default namespace — it can view pods, logs, services, events, and ConfigMaps, useful for debugging. The `deployer` SA also has a namespace-scoped Role — it can additionally create and update deployments and ConfigMaps, designed for CI/CD pipelines. I wrote a `generate-kubeconfig.sh` script that uses the Kubernetes TokenRequest API to generate a kubeconfig file for any of these accounts — the token expires in 24 hours so it's safe to hand out."*

---

### 9. "How do you monitor the cluster's health?"

*"Multiple layers. Prometheus scrapes 5 metric sources every 30 seconds — Node Exporter for hardware, Kube-State-Metrics for Kubernetes object state, Kubelet for containers, the API Server for request latency, and Falco for security event counts. I configured alert rules that fire on NodeDown, HighCPU above 80%, HighMemory above 85%, DiskSpaceLow below 15%, DiskSpaceCritical below 5%, PodCrashLooping, NodeNotReady, NginxPodsUnavailable, and more. Grafana shows all of it on pre-built dashboards. And I also wrote a `diagnose-services.sh` script that does a 14-point check — it runs from the master and checks everything from cluster connectivity to NFS reachability in one shot."*

---

### 10. "Why Flannel for the CNI?"

*"I chose Flannel because this is an 8GB RAM lab. Flannel is lightweight — it uses VXLAN overlay networking and only uses about 50MB of RAM per node. Calico would give me better NetworkPolicy performance and BGP routing, but it's heavier. Flannel is the standard choice for resource-constrained environments. The pod network CIDR I configured is 10.244.0.0/16."*

---

## 🧠 Key Numbers — Know These Cold

| What | Value |
|---|---|
| Kubernetes version | v1.35 |
| Container runtime | containerd |
| CNI plugin | Flannel (VXLAN, 10.244.0.0/16) |
| Ansible plays | 4 |
| Ansible roles | 4 — `common`, `k8s_master`, `k8s_worker`, `security` |
| Security role tasks | 34 |
| Setup time (automated) | ~15 minutes |
| Manual commands replaced | 50+ per node |
| NFS PersistentVolumes | 4 — 10Gi, 5Gi, 2Gi, 1Gi |
| etcd backup — local | Every hour, keep 24 hours |
| etcd backup — NFS | Every hour, keep 7 days |
| Prometheus scrape interval | Every 30 seconds |
| Monitoring sources | 5 — Node Exporter, KSM, Kubelet, API Server, Falco |
| Alert rules | 9 (NodeDown, HighCPU, HighMem, DiskLow, DiskCritical, PodCrashLoop, NodeNotReady, NginxPodsMissing, TargetDown) |
| Security layers | 4 — Host → Cluster → Network → Runtime |
| RBAC roles | 3 — `viewer` (ClusterRole), `developer` (Role), `deployer` (Role) |
| Token expiry | 24 hours (TokenRequest API) |
| Nginx replicas | 2 (with HPA auto-scaling) |
| Health check points | 14-point diagnostic script |
| Lab environment | 8GB RAM — 1 master + 1 worker + 1 NFS (VMware) |
| Ports | Prometheus :30090, Grafana :30300, Nginx :30080 |

---

## ⚠️ Never Say These — Common Mistakes

| ❌ You said / might say | ✅ What's actually correct |
|---|---|
| *"Master copies everything to worker"* | Master schedules pods onto the worker. Nothing is "copied." Worker runs the pods. |
| *"Worker takes over if master fails"* | Worker keeps existing pods running, but cannot do any new scheduling. You restore master from etcd backup. |
| *"Master self-heals"* | Master does NOT self-heal. You manually restore it from etcd backup snapshots. |
| *"DCDR"* | The correct terms are — **DR** (Disaster Recovery) for etcd backups, **self-healing** for pod restarts. |
| *"PBAC"* | The correct term is **RBAC** — Role-Based Access Control. |
| *"Flannel handles security"* | Flannel is the CNI for pod networking. Security is handled by NetworkPolicies, RBAC, PSS, and Falco. |
| *"I used Docker"* | Docker was deprecated as a K8s runtime in v1.24. I used **containerd**. |
| *"RBAC controls the whole cluster"* | `developer` and `deployer` are namespace-scoped Roles. Only `viewer` uses a ClusterRole for cluster-wide read access. |

---

## ⚡ 30-Second Version (For HR / Fast Rounds)

*"I automated the full deployment of a Kubernetes v1.35 cluster using Ansible — one command sets up the OS, installs Kubernetes on master and worker, connects them, deploys Prometheus and Grafana for monitoring, NFS persistent storage, Nginx as a demo app with autoscaling, and a 4-layer security setup — firewall hardening, RBAC, zero-trust Network Policies, and Falco for runtime threat detection. The whole cluster is up in 15 minutes, and I have automated hourly etcd backups to NFS for disaster recovery."*

---

## 🗺️ How to Flow Through a Real Interview

```
Interviewer: "Tell me about your project."
        ↓
→ Say Section 1 — the plain story (60-90 seconds)
        ↓
Interviewer: "Interesting, tell me more / walk me through it technically"
        ↓
→ Say Section 2 — the technical walk-through (2 minutes)
        ↓
Interviewer: Asks a specific question — Ansible, Falco, RBAC, storage, master failure...
        ↓
→ Pull the exact answer from Section 3
        ↓
Interviewer: "What was the hardest part?"
        ↓
→ "Getting the Flannel CNI and etcd backup working reliably —
   the timing of pod readiness checks between plays required
   careful retry logic in Ansible."
```

> **One final tip:** You'll sound most confident when you can say **why** you made each decision — not just what you did. Why Flannel over Calico? Why NFS over hostPath? Why etcd backups and not just snapshots? When you know the *reason*, you own the answer.

---

## 🏷️ Resume / LinkedIn Tags

`Kubernetes v1.35` · `Ansible` · `kubeadm` · `containerd` · `Ubuntu 22.04 LTS` · `Flannel CNI` · `Prometheus` · `Grafana` · `Node Exporter` · `Kube-State-Metrics` · `Falco` · `eBPF` · `UFW` · `CIS Benchmarks` · `RBAC` · `Pod Security Standards` · `NetworkPolicy` · `Zero-Trust Networking` · `NFS` · `PersistentVolumes` · `HPA` · `metrics-server` · `etcd` · `Disaster Recovery` · `Infrastructure-as-Code` · `DevOps` · `Linux`

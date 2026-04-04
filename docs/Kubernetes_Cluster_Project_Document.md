# Kubernetes Cluster Setup, Monitoring with Prometheus & Automation Using Ansible

---

## 📋 Project Information

| **Attribute**       | **Details**                                                              |
|---------------------|--------------------------------------------------------------------------|
| **Platform**        | DevOps                                                                   |
| **Duration**        | 2 Months                                                                 |
| **Operating System**| Ubuntu Linux 22.04 LTS                                                   |
| **Orchestration**   | Kubernetes v1.35 (kubeadm)                                               |
| **Automation**      | Ansible 2.9+                                                             |
| **Storage**         | TrueNAS (NFS) with PV/PVC                                                |
| **Monitoring**      | Prometheus + Grafana                                                     |
| **Networking**      | Calico CNI                                                               |
| **Sample Workload** | Nginx Web Server                                                         |

---

## � Hardware Requirements

### Minimum Requirements (8GB RAM - Lab/Development)

> ⚠️ **For 8GB Total RAM**: Use a **2-Node Setup** (1 Master + 1 Worker) with resource-optimized configurations.

| **Node**        | **vCPU** | **RAM**   | **Disk** | **Role**                              |
|-----------------|----------|-----------|----------|---------------------------------------|
| k8s-master      | 2        | 4 GB      | 30 GB    | Control Plane + Worker (taint removed)|
| k8s-worker1     | 2        | 4 GB      | 30 GB    | Worker Node                           |
| **Total**       | **4**    | **8 GB**  | **60 GB**|                                       |

### Recommended Requirements (16GB+ RAM - Full Setup)

| **Node**        | **vCPU** | **RAM**   | **Disk** | **Role**               |
|-----------------|----------|-----------|----------|------------------------|
| k8s-master      | 2        | 4 GB      | 50 GB    | Control Plane          |
| k8s-worker1     | 2        | 4 GB      | 50 GB    | Worker Node            |
| k8s-worker2     | 2        | 4 GB      | 50 GB    | Worker Node            |
| truenas         | 1        | 2 GB      | 100 GB   | NFS Storage            |
| **Total**       | **7**    | **14 GB** | **250 GB**|                       |

### Resource Optimization for 8GB Setup

#### 1. Allow Master Node to Run Workloads
```bash
# Remove the NoSchedule taint from master to use it as a worker too
kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane:NoSchedule-
```

#### 2. Use Lightweight CNI (Flannel instead of Calico)
```bash
# Flannel uses ~50MB RAM vs Calico's ~200MB
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

#### 3. Resource-Optimized Prometheus Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:latest
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          args:
            - '--storage.tsdb.retention.time=3d'  # Reduce retention
            - '--storage.tsdb.retention.size=1GB' # Limit storage
```

#### 4. Resource-Optimized Grafana Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:latest
          resources:
            requests:
              memory: "128Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "200m"
```

#### 5. Resource-Optimized Falco (Optional - Skip if RAM is critical)
```yaml
# For 8GB setup, Falco can be skipped or run with minimal config
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco
spec:
  template:
    spec:
      containers:
        - name: falco
          resources:
            requests:
              memory: "128Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "200m"
```

#### 6. Nginx with Minimal Resources
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2  # Reduced from 3
  template:
    spec:
      containers:
        - name: nginx
          image: nginx:alpine  # Smaller image
          resources:
            requests:
              memory: "32Mi"
              cpu: "25m"
            limits:
              memory: "64Mi"
              cpu: "100m"
```

### 8GB RAM Budget Breakdown

| **Component**          | **RAM Usage** | **Notes**                          |
|------------------------|---------------|------------------------------------|
| Ubuntu OS (per node)   | 500 MB × 2    | Base OS overhead                   |
| Kubelet + Containerd   | 300 MB × 2    | Kubernetes node components         |
| etcd                   | 200 MB        | Master only                        |
| API Server + Controller| 400 MB        | Master only                        |
| Flannel CNI            | 50 MB × 2     | Lightweight networking             |
| Prometheus             | 512 MB        | With retention limits              |
| Grafana                | 256 MB        | Single instance                    |
| Nginx (2 pods)         | 64 MB         | Alpine image                       |
| **Reserved Buffer**    | 500 MB        | For spikes                         |
| **Total Used**         | ~4.3 GB       | Leaves headroom for TrueNAS/Falco  |

### VM Configuration Tips

1. **Disable GUI**: Use Ubuntu Server (no desktop)
2. **Swap**: Disable swap completely (Kubernetes requirement)
3. **Use SSD**: Improves etcd and container performance
4. **Thin Provisioning**: Use thin-provisioned virtual disks

---


## �📝 Project Description

This project implements an **automated, production-ready Kubernetes cluster** using Ansible and kubeadm on Ubuntu Linux. The infrastructure is designed with enterprise-grade features including:

- **Platform-level DCDR (Disaster Recovery)**: Automated failover and recovery mechanisms
- **Self-Healing Capabilities**: Pod restarts and workload rescheduling via Kubernetes controllers
- **Persistent Storage**: TrueNAS NFS integration using PersistentVolume (PV) and PersistentVolumeClaim (PVC)
- **Complete Observability**: Prometheus for metrics collection and Grafana for visualization
- **Security Hardening**: Implementation of CIS benchmarks, Network Policies, and RBAC
- **Pod Security Standards (PSS)**: Modern pod security enforcement replacing deprecated PodSecurityPolicy
- **Runtime Security**: Falco for real-time threat detection and anomaly monitoring

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              KUBERNETES CLUSTER                                  │
│                                                                                  │
│    ┌───────────────────────────────────────────────────────────────────────┐    │
│    │                        CONTROL PLANE (Master Node)                     │    │
│    │                                                                        │    │
│    │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │    │
│    │   │ API Server  │  │    etcd     │  │  Scheduler  │  │ Controller  │  │    │
│    │   │   :6443     │  │  :2379-2380 │  │   Manager   │  │   Manager   │  │    │
│    │   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │    │
│    │                                                                        │    │
│    └────────────────────────────────┬───────────────────────────────────────┘    │
│                                     │                                            │
│                          ┌──────────┴──────────┐                                 │
│                          │   Kubernetes API    │                                 │
│                          └──────────┬──────────┘                                 │
│                                     │                                            │
│    ┌────────────────────────────────┼────────────────────────────────────┐      │
│    │                                │                                     │      │
│    │    ┌───────────────────┐       │       ┌───────────────────┐        │      │
│    │    │   WORKER NODE 1   │       │       │   WORKER NODE 2   │        │      │
│    │    │                   │       │       │                   │        │      │
│    │    │  ┌─────────────┐  │       │       │  ┌─────────────┐  │        │      │
│    │    │  │   Kubelet   │  │       │       │  │   Kubelet   │  │        │      │
│    │    │  └─────────────┘  │       │       │  └─────────────┘  │        │      │
│    │    │  ┌─────────────┐  │       │       │  ┌─────────────┐  │        │      │
│    │    │  │ Kube-proxy  │  │       │       │  │ Kube-proxy  │  │        │      │
│    │    │  └─────────────┘  │       │       │  └─────────────┘  │        │      │
│    │    │  ┌─────────────┐  │       │       │  ┌─────────────┐  │        │      │
│    │    │  │ Containerd  │  │       │       │  │ Containerd  │  │        │      │
│    │    │  └─────────────┘  │       │       │  └─────────────┘  │        │      │
│    │    │  ┌─────────────┐  │       │       │  ┌─────────────┐  │        │      │
│    │    │  │   Calico    │  │       │       │  │   Calico    │  │        │      │
│    │    │  └─────────────┘  │       │       │  └─────────────┘  │        │      │
│    │    └───────────────────┘       │       └───────────────────┘        │      │
│    │                                │                                     │      │
│    │              DATA PLANE (Worker Nodes)                               │      │
│    └────────────────────────────────┼────────────────────────────────────┘      │
│                                     │                                            │
└─────────────────────────────────────┼────────────────────────────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
              ▼                       ▼                       ▼
    ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
    │   PROMETHEUS    │     │    GRAFANA      │     │     NGINX       │
    │   (Monitoring)  │     │  (Dashboards)   │     │   (Workload)    │
    │    :30090       │     │    :30300       │     │    :30080       │
    └─────────────────┘     └─────────────────┘     └─────────────────┘
              │                       │                       │
              └───────────────────────┼───────────────────────┘
                                      │
                                      ▼
                        ┌─────────────────────────┐
                        │    TRUENAS NFS STORAGE  │
                        │                         │
                        │  /mnt/pool/kubernetes   │
                        │     (PV / PVC)          │
                        └─────────────────────────┘
```

---

## 🔧 Technology Stack

| **Component**       | **Technology**           | **Version** | **Purpose**                                    |
|---------------------|--------------------------|-------------|------------------------------------------------|
| Operating System    | Ubuntu Linux             | 22.04 LTS   | Host operating system for all nodes            |
| Container Runtime   | Containerd               | 1.7.x       | Container runtime (CRI-compliant)              |
| Orchestration       | Kubernetes               | 1.35.x      | Container orchestration platform               |
| Cluster Bootstrap   | kubeadm                  | 1.35.x      | Cluster initialization and management          |
| Automation          | Ansible                  | 2.9+        | Infrastructure as Code (IaC)                   |
| CNI Plugin          | Calico                   | 3.26.x      | Pod networking and network policies            |
| Storage Backend     | TrueNAS                  | Latest      | NFS-based persistent storage                   |
| Metrics Collection  | Prometheus               | Latest      | Time-series metrics collection                 |
| Visualization       | Grafana                  | Latest      | Metrics dashboards and alerting                |
| Runtime Security    | Falco                    | 0.37.x      | Real-time threat detection and anomaly alerts  |
| Sample Application  | Nginx                    | Latest      | Web server workload for testing                |

---

## 📁 Project Directory Structure

```
kubernetes-cluster-project/
│
├── ansible/                              # Ansible Automation
│   ├── inventory/
│   │   └── hosts.ini                     # Server inventory definition
│   │
│   ├── group_vars/
│   │   └── all.yml                       # Global variables (IPs, versions, etc.)
│   │
│   ├── roles/
│   │   ├── common/                       # Common setup for all nodes
│   │   │   ├── tasks/
│   │   │   │   └── main.yml              # Prerequisites, dependencies
│   │   │   └── handlers/
│   │   │       └── main.yml              # Service restart handlers
│   │   │
│   │   ├── k8s_master/                   # Control plane setup
│   │   │   ├── tasks/
│   │   │   │   └── main.yml              # kubeadm init, CNI installation
│   │   │   └── handlers/
│   │   │       └── main.yml              # Kubelet restart handler
│   │   │
│   │   ├── k8s_worker/                   # Worker node setup
│   │   │   └── tasks/
│   │   │       └── main.yml              # Join cluster using token
│   │   │
│   │   └── security/                     # Security hardening
│   │       ├── tasks/
│   │       │   └── main.yml              # Firewall, SSH, CIS benchmarks
│   │       └── handlers/
│   │           └── main.yml              # SSH/Firewall restart handlers
│   │
│   └── site.yml                          # Main orchestration playbook
│
├── kubernetes/                           # Kubernetes Manifests
│   ├── monitoring/
│   │   ├── namespace.yaml                # monitoring namespace
│   │   ├── prometheus-config.yaml        # Prometheus ConfigMap
│   │   ├── prometheus-deployment.yaml    # Prometheus Deployment + Service
│   │   ├── prometheus-rbac.yaml          # ServiceAccount, ClusterRole
│   │   ├── grafana-deployment.yaml       # Grafana Deployment + Service
│   │   └── grafana-datasource.yaml       # Prometheus datasource config
│   │
│   ├── storage/
│   │   ├── nfs-pv.yaml                   # NFS PersistentVolume
│   │   ├── nfs-pvc.yaml                  # PersistentVolumeClaim
│   │   └── storage-class.yaml            # StorageClass definition
│   │
│   ├── nginx/
│   │   ├── namespace.yaml                # Optional: nginx namespace
│   │   ├── deployment.yaml               # Nginx Deployment (3 replicas)
│   │   ├── service.yaml                  # NodePort Service
│   │   └── pvc.yaml                      # PVC for nginx data
│   │
│   ├── security/
│   │   ├── network-policy.yaml           # Network policy rules
│   │   ├── rbac.yaml                     # RBAC roles and bindings
│   │   └── pod-security-standards.yaml   # PSS namespace labels
│   │
│   └── falco/
│       ├── falco-daemonset.yaml          # Falco deployment
│       ├── falco-config.yaml             # Falco configuration
│       └── falco-rules.yaml              # Custom detection rules
│
├── docs/
│   └── setup_guide.md                    # Step-by-step setup instructions
│
└── README.md                             # Project overview
```

---

## 🔄 Implementation Workflow

### Phase 1: Infrastructure Preparation (Week 1-2)

| **Task**                              | **Description**                                            |
|---------------------------------------|------------------------------------------------------------|
| Server Provisioning                   | Provision 3+ Ubuntu 22.04 VMs (1 master, 2+ workers)       |
| Network Configuration                 | Configure static IPs, DNS resolution, host entries         |
| SSH Key Setup                         | Generate and distribute SSH keys for Ansible               |
| TrueNAS Configuration                 | Create NFS dataset and configure share                     |
| Ansible Control Node Setup            | Install Ansible on control machine                         |

### Phase 2: Kubernetes Cluster Deployment (Week 3-4)

| **Task**                              | **Description**                                            |
|---------------------------------------|------------------------------------------------------------|
| Common Role Execution                 | Install containerd, kubelet, kubeadm, kubectl              |
| Master Node Initialization            | Run kubeadm init, install Calico CNI                       |
| Worker Node Join                      | Join workers using cluster token                           |
| Cluster Verification                  | Verify all nodes are in Ready state                        |

### Phase 3: Storage Integration (Week 5)

| **Task**                              | **Description**                                            |
|---------------------------------------|------------------------------------------------------------|
| NFS Mount Testing                     | Verify NFS connectivity from all nodes                     |
| PersistentVolume Creation             | Create PV pointing to TrueNAS NFS share                    |
| PersistentVolumeClaim Creation        | Create PVC for application storage                         |
| StorageClass Configuration            | Optional: Dynamic provisioning setup                       |

### Phase 4: Monitoring Stack Deployment (Week 6)

| **Task**                              | **Description**                                            |
|---------------------------------------|------------------------------------------------------------|
| Prometheus Deployment                 | Deploy Prometheus with cluster-wide scraping               |
| Grafana Deployment                    | Deploy Grafana with Prometheus datasource                  |
| Dashboard Import                      | Import Kubernetes monitoring dashboards                    |
| Alert Rules Configuration             | Configure basic alerting rules                             |

### Phase 5: Security Hardening (Week 7)

| **Task**                              | **Description**                                            |
|---------------------------------------|------------------------------------------------------------|
| RBAC Configuration                    | Create roles, service accounts, role bindings              |
| Network Policies                      | Implement pod-to-pod communication restrictions            |
| CIS Benchmark Application             | Apply CIS Kubernetes security benchmarks                   |
| Firewall Rules                        | Configure UFW on all nodes                                 |
| SSH Hardening                         | Disable root login, enforce key-based auth                 |

### Phase 6: Application Deployment & Testing (Week 8)

| **Task**                              | **Description**                                            |
|---------------------------------------|------------------------------------------------------------|
| Nginx Deployment                      | Deploy Nginx with 3 replicas                               |
| Self-Healing Testing                  | Delete pods and verify automatic recreation                |
| Storage Testing                       | Verify PVC mount and data persistence                      |
| Monitoring Validation                 | Verify metrics in Prometheus and Grafana                   |
| Load Testing                          | Basic load testing of the application                      |

---

## 📋 Detailed Component Specifications

### 1. Ansible Automation

#### Inventory Configuration (hosts.ini)
```ini
[masters]
k8s-master ansible_host=192.168.1.10

[workers]
k8s-worker1 ansible_host=192.168.1.11
k8s-worker2 ansible_host=192.168.1.12

[k8s_cluster:children]
masters
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
```

#### Global Variables (all.yml)
```yaml
# Kubernetes Configuration
kubernetes_version: "1.35"
pod_network_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"

# Container Runtime
container_runtime: "containerd"

# TrueNAS NFS Storage
nfs_server: "192.168.1.100"
nfs_path: "/mnt/pool/kubernetes"

# Monitoring
prometheus_nodeport: 30090
grafana_nodeport: 30300
```

#### Common Role Tasks
The common role performs these operations on all nodes:

1. **System Update**: Update apt cache and upgrade packages
2. **Disable Swap**: Permanently disable swap (required by Kubernetes)
3. **Load Kernel Modules**: Load overlay, br_netfilter modules
4. **Sysctl Configuration**: Enable IP forwarding, bridge-nf-call-iptables
5. **Install Containerd**: Install and configure containerd runtime
6. **Install Kubernetes Tools**: Install kubelet, kubeadm, kubectl
7. **Hold Package Versions**: Prevent automatic upgrades

#### Master Role Tasks
The k8s_master role initializes the control plane:

1. **Check Cluster Status**: Verify if cluster is already initialized
2. **Initialize Cluster**: Run `kubeadm init` with pod network CIDR
3. **Configure kubectl**: Setup kubeconfig for root and ubuntu users
4. **Install Calico CNI**: Apply Calico manifests for networking
5. **Generate Join Token**: Create token for worker node joining
6. **Store Join Command**: Save join command for worker nodes

#### Worker Role Tasks
The k8s_worker role joins nodes to the cluster:

1. **Check Node Status**: Verify if already part of cluster
2. **Fetch Join Command**: Get join command from master
3. **Join Cluster**: Execute kubeadm join command

#### Security Role Tasks
The security role hardens the infrastructure:

1. **Firewall Configuration**: Enable UFW with necessary ports
2. **SSH Hardening**: Disable root login, enforce key-based auth
3. **File Permissions**: Set secure permissions on config files
4. **Kernel Parameters**: Apply security-related sysctl settings

---

### 2. Kubernetes Resources

#### NFS PersistentVolume
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-storage
  nfs:
    server: 192.168.1.100
    path: /mnt/pool/kubernetes
```

#### PersistentVolumeClaim
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-storage
  resources:
    requests:
      storage: 10Gi
```

#### Prometheus Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
        - name: prometheus
          image: prom/prometheus:latest
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
      volumes:
        - name: config
          configMap:
            name: prometheus-config
```

#### Grafana Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:latest
          ports:
            - containerPort: 3000
          env:
            - name: GF_SECURITY_ADMIN_PASSWORD
              value: "admin"
```

#### Nginx Deployment with Self-Healing
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 3                    # High availability
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
          livenessProbe:          # Self-healing probe
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 5
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 3
          volumeMounts:
            - name: nginx-html
              mountPath: /usr/share/nginx/html
            - name: nginx-cache
              mountPath: /var/cache/nginx
            - name: nginx-run
              mountPath: /var/run
      volumes:
        - name: nginx-html
          persistentVolumeClaim:
            claimName: nginx-pvc          # NFS-backed persistent web content
        - name: nginx-cache
          emptyDir: {}                    # Ephemeral cache (recreated per pod)
        - name: nginx-run
          emptyDir: {}                    # Ephemeral PID file
```

---

### 3. Security Implementation

#### Network Policy Example
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nginx-ingress
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: nginx
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 80
```

#### RBAC Configuration
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
  - apiGroups: [""]
    resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["extensions"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch"]
  - nonResourceURLs: ["/metrics"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
```

#### CIS Benchmark Checklist

| **CIS Control**                                | **Implementation**                                       |
|-----------------------------------------------|---------------------------------------------------------|
| 1.1.1 - API Server anonymous auth disabled    | `--anonymous-auth=false` in API server config            |
| 1.2.1 - Audit logging enabled                 | Configure audit policy in API server                     |
| 2.1 - etcd encryption at rest                 | Configure encryption-provider-config                     |
| 3.1 - Authentication/Authorization            | RBAC enabled, no anonymous access                        |
| 4.1 - Worker node security                    | Kubelet authentication/authorization enabled             |
| 5.1 - Network policies                        | Default deny with explicit allow rules                   |
| 5.2 - Pod security standards                  | Restricted PSS applied to namespaces                     |

---

### 4. Pod Security Standards (PSS) - Replacing PodSecurityPolicy

> **Note**: PodSecurityPolicy (PSP) was deprecated in Kubernetes v1.21 and removed in v1.25. Pod Security Standards (PSS) with Pod Security Admission (PSA) is the modern replacement.

#### PSS Levels Explained

| **Level**      | **Description**                                                                 |
|----------------|---------------------------------------------------------------------------------|
| **Privileged** | Unrestricted policy, allowing all privileges (for system workloads)             |
| **Baseline**   | Minimally restrictive, prevents known privilege escalations                     |
| **Restricted** | Heavily restricted, follows security best practices (recommended for apps)      |

#### Applying PSS to Namespaces

PSS is enforced using namespace labels. There are three modes:
- **enforce**: Violations reject pod creation
- **audit**: Violations are logged but pods are allowed
- **warn**: Violations trigger user-facing warnings

```yaml
# Apply Restricted PSS to default namespace
apiVersion: v1
kind: Namespace
metadata:
  name: default
  labels:
    # Enforce restricted security standard
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    # Audit and warn for violations
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

#### PSS for Monitoring Namespace (Baseline)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
```

#### PSS-Compliant Pod Configuration
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-nginx
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 1000
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
  volumes:
    - name: tmp
      emptyDir: {}
    - name: cache
      emptyDir: {}
    - name: run
      emptyDir: {}
```

#### Verifying PSS Enforcement
```bash
# Check namespace labels
kubectl get namespace default --show-labels

# Test a privileged pod (should fail in restricted namespace)
kubectl run test-privileged --image=nginx --privileged=true
# Expected: Error - pod would violate PodSecurity "restricted:latest"

# View PSS audit logs
kubectl logs -n kube-system -l component=kube-apiserver | grep "PodSecurity"
```

---

### 5. Runtime Security with Falco 🦅

> **Falco** is a cloud-native runtime security tool that detects unexpected application behavior and threats at runtime. It monitors system calls from the Linux kernel and alerts on suspicious activity.

#### Why Falco Makes This Project Stand Out

| **Feature**                    | **How It Helps**                                                    |
|--------------------------------|---------------------------------------------------------------------|
| Real-time Threat Detection     | Detects container escapes, shell spawning, file tampering           |
| Kernel-level Monitoring        | Uses eBPF/kernel module to capture syscalls                         |
| Pre-built Rules                | 100+ rules for Kubernetes, containers, and Linux                    |
| Custom Rules                   | Define organization-specific security policies                      |
| Integration with Prometheus    | Export metrics for alerting via Grafana                             |

#### Falco Architecture in the Cluster

```
┌─────────────────────────────────────────────────────────────────┐
│                        KUBERNETES CLUSTER                        │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                    FALCO DAEMONSET                        │  │
│   │  (Runs on every node to monitor all container activity)  │  │
│   └────────────────────────┬─────────────────────────────────┘  │
│                            │                                     │
│            ┌───────────────┼───────────────┐                     │
│            ▼               ▼               ▼                     │
│    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│    │   Node 1    │ │   Node 2    │ │   Node 3    │              │
│    │             │ │             │ │             │              │
│    │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────┐ │              │
│    │ │ Falco   │ │ │ │ Falco   │ │ │ │ Falco   │ │              │
│    │ │ Agent   │ │ │ │ Agent   │ │ │ │ Agent   │ │              │
│    │ └────┬────┘ │ │ └────┬────┘ │ │ └────┬────┘ │              │
│    │      │      │ │      │      │ │      │      │              │
│    │      ▼      │ │      ▼      │ │      ▼      │              │
│    │  syscalls   │ │  syscalls   │ │  syscalls   │              │
│    │  (kernel)   │ │  (kernel)   │ │  (kernel)   │              │
│    └─────────────┘ └─────────────┘ └─────────────┘              │
│                            │                                     │
│                            ▼                                     │
│              ┌─────────────────────────┐                         │
│              │     PROMETHEUS          │                         │
│              │  (Falco Metrics Export) │                         │
│              └─────────────────────────┘                         │
│                            │                                     │
│                            ▼                                     │
│              ┌─────────────────────────┐                         │
│              │       GRAFANA           │                         │
│              │  (Security Dashboard)   │                         │
│              └─────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

#### Falco DaemonSet Deployment
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco
  labels:
    app: falco
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      serviceAccountName: falco
      hostNetwork: true
      hostPID: true
      containers:
        - name: falco
          image: falcosecurity/falco-no-driver:0.37.1
          securityContext:
            privileged: true
          args:
            - /usr/bin/falco
            - --cri
            - /run/containerd/containerd.sock
            - -pk
          volumeMounts:
            - name: containerd-socket
              mountPath: /run/containerd/containerd.sock
              readOnly: true
            - name: proc
              mountPath: /host/proc
              readOnly: true
            - name: boot
              mountPath: /host/boot
              readOnly: true
            - name: lib-modules
              mountPath: /host/lib/modules
              readOnly: true
            - name: usr
              mountPath: /host/usr
              readOnly: true
            - name: etc
              mountPath: /host/etc
              readOnly: true
            - name: falco-config
              mountPath: /etc/falco
      volumes:
        - name: containerd-socket
          hostPath:
            path: /run/containerd/containerd.sock
        - name: proc
          hostPath:
            path: /proc
        - name: boot
          hostPath:
            path: /boot
        - name: lib-modules
          hostPath:
            path: /lib/modules
        - name: usr
          hostPath:
            path: /usr
        - name: etc
          hostPath:
            path: /etc
        - name: falco-config
          configMap:
            name: falco-config
```

#### Falco Custom Rules for This Project
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-rules
  namespace: falco
data:
  custom_rules.yaml: |-
    # Rule 1: Detect shell spawned inside container
    - rule: Shell Spawned in Container
      desc: Detects when a shell is spawned inside a container
      condition: >
        spawned_process and
        container and
        proc.name in (bash, sh, zsh, ksh, csh, ash)
      output: >
        Shell spawned in container
        (user=%user.name container=%container.name
        shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline
        container_id=%container.id image=%container.image.repository)
      priority: WARNING
      tags: [container, shell]

    # Rule 2: Detect sensitive file access
    - rule: Read Sensitive File in Container
      desc: Detects attempts to read sensitive files
      condition: >
        open_read and
        container and
        fd.name in (/etc/shadow, /etc/passwd, /etc/kubernetes/admin.conf)
      output: >
        Sensitive file read attempt in container
        (user=%user.name file=%fd.name container=%container.name
        image=%container.image.repository)
      priority: CRITICAL
      tags: [container, filesystem, sensitive]

    # Rule 3: Detect kubectl exec into container
    - rule: Kubectl Exec Detected
      desc: Detects kubectl exec commands into running containers
      condition: >
        spawned_process and
        container and
        proc.pname = "runc:[2:INIT]"
      output: >
        Kubectl exec or similar detected
        (user=%user.name container=%container.name
        command=%proc.cmdline)
      priority: NOTICE
      tags: [container, exec]

    # Rule 4: Detect container drift (new executable)
    - rule: Container Drift Detected
      desc: New executable created in container after startup
      condition: >
        spawned_process and
        container and
        proc.is_exe_from_memfd=true
      output: >
        Container drift detected - new executable
        (container=%container.name process=%proc.name
        image=%container.image.repository)
      priority: CRITICAL
      tags: [container, drift]

    # Rule 5: Detect outbound connection to suspicious port
    - rule: Outbound Connection to Mining Pool
      desc: Detects outbound connections to known mining pool ports
      condition: >
        outbound and
        container and
        fd.sport in (3333, 4444, 5555, 7777, 8888, 9999, 14444, 14433)
      output: >
        Possible cryptocurrency mining detected
        (container=%container.name connection=%fd.name
        port=%fd.sport image=%container.image.repository)
      priority: CRITICAL
      tags: [container, network, cryptomining]
```

#### Falco Metrics for Prometheus
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-config
  namespace: falco
data:
  falco.yaml: |-
    json_output: true
    json_include_output_property: true
    log_stderr: true
    log_syslog: false
    log_level: info
    priority: debug
    
    # Enable Prometheus metrics export
    webserver:
      enabled: true
      listen_port: 8765
      k8s_healthz_endpoint: /healthz
      ssl_enabled: false
    
    # Prometheus metrics endpoint
    metrics:
      enabled: true
      interval: 1h
      output_rule: true
      rules_counters_enabled: true
      resource_utilization_enabled: true
```

#### Prometheus ServiceMonitor for Falco
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: falco
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: falco
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

#### Viewing Falco Alerts
```bash
# View real-time Falco logs across all nodes
kubectl logs -n falco -l app=falco -f

# Filter for high-priority alerts only
kubectl logs -n falco -l app=falco | grep -E "Warning|Critical"

# Check Falco pod status on all nodes
kubectl get pods -n falco -o wide
```

#### Falco Integration Flow in This Project

| **Step** | **Action**                                    | **Result**                                         |
|----------|-----------------------------------------------|----------------------------------------------------|
| 1        | Attacker gains shell access to nginx pod      | Falco detects "Shell Spawned in Container"         |
| 2        | Attacker tries to read /etc/shadow            | Falco raises CRITICAL "Sensitive File Read"        |
| 3        | Alert exported to Prometheus metrics          | falco_alerts metric increments                     |
| 4        | Grafana dashboard shows security event        | SOC team is alerted via Grafana notification       |
| 5        | Investigation and remediation                 | Pod terminated, image rebuilt                      |

---

#### Firewall Rules (UFW)

| **Port**    | **Protocol** | **Purpose**                    | **Nodes**      |
|-------------|--------------|--------------------------------|----------------|
| 22          | TCP          | SSH access                     | All            |
| 6443        | TCP          | Kubernetes API Server          | Master         |
| 2379-2380   | TCP          | etcd server client API         | Master         |
| 10250       | TCP          | Kubelet API                    | All            |
| 10251       | TCP          | kube-scheduler                 | Master         |
| 10252       | TCP          | kube-controller-manager        | Master         |
| 30000-32767 | TCP          | NodePort Services              | All            |
| 179         | TCP          | Calico BGP                     | All            |
| 4789        | UDP          | Calico VXLAN                   | All            |
| 8765        | TCP          | Falco Metrics                  | All            |

---

## 🖥️ Service Access

| **Service**    | **Access URL**               | **Port** | **Credentials**     |
|----------------|------------------------------|----------|---------------------|
| Kubernetes API | https://<master-ip>:6443     | 6443     | kubeconfig token    |
| Prometheus     | http://<node-ip>:30090       | 30090    | N/A                 |
| Grafana        | http://<node-ip>:30300       | 30300    | admin / K8sGrafana@2024!       |
| Nginx          | http://<node-ip>:30080       | 30080    | N/A                 |

---

## 🧪 Self-Healing Demonstration

### Pod Restart Test
```bash
# List running nginx pods
kubectl get pods -l app=nginx

# Delete a pod to trigger self-healing
kubectl delete pod <nginx-pod-name>

# Watch automatic pod recreation
kubectl get pods -l app=nginx -w
```

### Node Failure Simulation
```bash
# Cordon a node (mark as unschedulable)
kubectl cordon k8s-worker1

# Drain the node (evict pods)
kubectl drain k8s-worker1 --ignore-daemonsets --delete-emptydir-data

# Observe pods rescheduled to other nodes
kubectl get pods -o wide

# Uncordon node when recovered
kubectl uncordon k8s-worker1
```

---

## � Backup & Disaster Recovery

### Why Backup etcd?

> **etcd** is the brain of your Kubernetes cluster. It stores ALL cluster state including:
> - Pod definitions and configurations
> - Secrets and ConfigMaps
> - Service accounts and RBAC policies
> - PersistentVolume claims
> - Custom Resource Definitions (CRDs)
> 
> **If etcd is lost without backup, your entire cluster configuration is lost.**

### Backup Strategy Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     ETCD BACKUP STRATEGY                                 │
│                                                                          │
│   ┌─────────────────┐       ┌─────────────────┐       ┌──────────────┐  │
│   │   ETCD DATA     │──────▶│  SNAPSHOT       │──────▶│   BACKUP     │  │
│   │   (Live Data)   │       │  (etcdctl)      │       │   STORAGE    │  │
│   └─────────────────┘       └─────────────────┘       └──────────────┘  │
│                                                              │           │
│                                                              ▼           │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                     BACKUP LOCATIONS                             │   │
│   │                                                                  │   │
│   │   ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐   │   │
│   │   │   Local     │   │   TrueNAS   │   │   Off-site/Cloud    │   │   │
│   │   │   /backup   │   │   NFS Share │   │   (S3/GCS/Azure)    │   │   │
│   │   └─────────────┘   └─────────────┘   └─────────────────────┘   │   │
│   │                                                                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   BACKUP SCHEDULE:                                                       │
│   • Hourly:  Rotate last 24 snapshots                                   │
│   • Daily:   Rotate last 7 snapshots                                    │
│   • Weekly:  Rotate last 4 snapshots                                    │
│   • Monthly: Keep indefinitely                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1. Manual etcd Backup

#### Prerequisites
```bash
# Verify etcdctl is installed
etcdctl version

# Find etcd pod (for kubeadm clusters)
kubectl get pods -n kube-system | grep etcd
```

#### Taking a Snapshot
```bash
# Set environment variables for etcd access
export ETCDCTL_API=3
export ETCD_ENDPOINTS="https://127.0.0.1:2379"
export ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
export ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
export ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"

# Create backup directory
sudo mkdir -p /backup/etcd

# Take snapshot with timestamp
BACKUP_FILE="/backup/etcd/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db"

sudo etcdctl snapshot save $BACKUP_FILE \
  --endpoints=$ETCD_ENDPOINTS \
  --cacert=$ETCD_CACERT \
  --cert=$ETCD_CERT \
  --key=$ETCD_KEY

# Verify snapshot
sudo etcdctl snapshot status $BACKUP_FILE --write-out=table
```

#### Expected Output
```
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 4e2f3a1b |    28954 |       1247 |     5.2 MB |
+----------+----------+------------+------------+
```

### 2. Automated Backup Script

#### Backup Script (etcd-backup.sh)
```bash
#!/bin/bash
# =============================================================================
# ETCD Automated Backup Script for Kubernetes
# =============================================================================
# Schedule with cron: 0 * * * * /opt/scripts/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1
# =============================================================================

set -euo pipefail

# Configuration
BACKUP_DIR="/backup/etcd"
NFS_BACKUP_DIR="/mnt/truenas/etcd-backups"
RETENTION_HOURS=24
RETENTION_DAYS=7
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="etcd-snapshot-${DATE}.db"

# etcd Configuration
export ETCDCTL_API=3
ENDPOINTS="https://127.0.0.1:2379"
CACERT="/etc/kubernetes/pki/etcd/ca.crt"
CERT="/etc/kubernetes/pki/etcd/server.crt"
KEY="/etc/kubernetes/pki/etcd/server.key"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Create backup directories if not exist
mkdir -p "${BACKUP_DIR}"
mkdir -p "${NFS_BACKUP_DIR}" 2>/dev/null || true

log "Starting etcd backup..."

# Take snapshot
etcdctl snapshot save "${BACKUP_DIR}/${BACKUP_NAME}" \
    --endpoints="${ENDPOINTS}" \
    --cacert="${CACERT}" \
    --cert="${CERT}" \
    --key="${KEY}"

# Verify snapshot
etcdctl snapshot status "${BACKUP_DIR}/${BACKUP_NAME}" --write-out=json > /dev/null
if [ $? -eq 0 ]; then
    log "Snapshot verified: ${BACKUP_NAME}"
else
    log "ERROR: Snapshot verification failed!"
    exit 1
fi

# Copy to NFS (TrueNAS)
if [ -d "${NFS_BACKUP_DIR}" ]; then
    cp "${BACKUP_DIR}/${BACKUP_NAME}" "${NFS_BACKUP_DIR}/"
    log "Backup copied to NFS: ${NFS_BACKUP_DIR}/${BACKUP_NAME}"
fi

# Cleanup old backups (keep last 24 hourly backups locally)
log "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "etcd-snapshot-*.db" -mmin +$((RETENTION_HOURS * 60)) -delete

# Cleanup NFS backups (keep last 7 days)
if [ -d "${NFS_BACKUP_DIR}" ]; then
    find "${NFS_BACKUP_DIR}" -name "etcd-snapshot-*.db" -mtime +${RETENTION_DAYS} -delete
fi

log "Backup completed successfully: ${BACKUP_NAME}"

# Optional: Send alert on success (integrate with Prometheus Alertmanager)
# curl -X POST http://alertmanager:9093/api/v1/alerts -d '[{"labels":{"alertname":"EtcdBackupSuccess"}}]'
```

#### Cron Configuration
```bash
# Edit crontab
sudo crontab -e

# Add these lines for automated backup schedule
# Hourly backup
0 * * * * /opt/scripts/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1

# Daily backup at midnight (separate directory)
0 0 * * * /opt/scripts/etcd-backup.sh daily >> /var/log/etcd-backup.log 2>&1
```

### 3. etcd Restore Procedure

> ⚠️ **WARNING**: Restoring etcd will REPLACE your current cluster state. Only perform this in disaster recovery scenarios.

#### Restore Steps

```bash
# Step 1: Stop kube-apiserver and etcd
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# Wait for pods to stop
sleep 30

# Step 2: Backup current etcd data (just in case)
sudo mv /var/lib/etcd /var/lib/etcd.backup.$(date +%Y%m%d)

# Step 3: Restore from snapshot
SNAPSHOT_FILE="/backup/etcd/etcd-snapshot-20260201-120000.db"

sudo etcdctl snapshot restore $SNAPSHOT_FILE \
    --data-dir=/var/lib/etcd \
    --initial-cluster="k8s-master=https://192.168.1.10:2380" \
    --initial-cluster-token="etcd-cluster" \
    --initial-advertise-peer-urls="https://192.168.1.10:2380" \
    --name="k8s-master"

# Step 4: Set correct ownership
sudo chown -R etcd:etcd /var/lib/etcd

# Step 5: Restart etcd and API server
sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
sleep 30
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# Step 6: Verify cluster health
kubectl get nodes
kubectl get pods --all-namespaces
```

### 4. Ansible Role for etcd Backup

#### Backup Role Tasks (roles/etcd_backup/tasks/main.yml)
```yaml
---
# Ansible role for automated etcd backup setup

- name: Create backup directories
  file:
    path: "{{ item }}"
    state: directory
    mode: '0700'
    owner: root
    group: root
  loop:
    - /backup/etcd
    - /opt/scripts

- name: Copy etcd backup script
  template:
    src: etcd-backup.sh.j2
    dest: /opt/scripts/etcd-backup.sh
    mode: '0755'
    owner: root
    group: root

- name: Mount TrueNAS NFS for backups
  mount:
    path: /mnt/truenas/etcd-backups
    src: "{{ nfs_server }}:{{ nfs_backup_path }}"
    fstype: nfs
    opts: defaults,_netdev
    state: mounted

- name: Setup hourly backup cron job
  cron:
    name: "etcd hourly backup"
    minute: "0"
    job: "/opt/scripts/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1"
    user: root

- name: Setup daily backup cron job
  cron:
    name: "etcd daily backup"
    minute: "0"
    hour: "0"
    job: "/opt/scripts/etcd-backup.sh daily >> /var/log/etcd-backup.log 2>&1"
    user: root

- name: Take initial backup
  shell: /opt/scripts/etcd-backup.sh
  args:
    creates: /backup/etcd/etcd-snapshot-*.db
```

### 5. Disaster Recovery Scenarios

| **Scenario**                          | **Recovery Action**                                    | **RTO**   |
|---------------------------------------|-------------------------------------------------------|-----------|
| Single etcd member failure            | Rejoin or replace member                               | 15 min    |
| etcd data corruption                  | Restore from latest snapshot                           | 30 min    |
| Master node failure (hardware)        | Provision new node, restore etcd                       | 1-2 hours |
| Complete cluster loss                 | Restore etcd + reinstall workers                       | 2-4 hours |
| Accidental namespace/resource deletion| Restore from snapshot before deletion                  | 30 min    |

### 6. Backup Verification Checklist

- [ ] Verify backup script runs without errors: `sudo /opt/scripts/etcd-backup.sh`
- [ ] Check backup file exists: `ls -la /backup/etcd/`
- [ ] Verify snapshot integrity: `etcdctl snapshot status <backup-file> --write-out=table`
- [ ] Confirm NFS backup: `ls -la /mnt/truenas/etcd-backups/`
- [ ] Test restore on non-production environment
- [ ] Check cron job is active: `sudo crontab -l`
- [ ] Review backup logs: `tail -f /var/log/etcd-backup.log`

### 7. Monitoring Backup Status with Prometheus

```yaml
# Prometheus alert rule for backup monitoring
groups:
  - name: etcd-backup-alerts
    rules:
      - alert: EtcdBackupMissing
        expr: time() - etcd_backup_last_success_timestamp_seconds > 7200
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "etcd backup is overdue"
          description: "No successful etcd backup in the last 2 hours"
      
      - alert: EtcdBackupFailed
        expr: etcd_backup_last_status == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "etcd backup failed"
          description: "The last etcd backup attempt has failed"
```

### 8. Best Practices

| **Practice**                          | **Recommendation**                                     |
|---------------------------------------|--------------------------------------------------------|
| Backup Frequency                      | Minimum hourly, critical systems every 15 min          |
| Retention Policy                      | 24 hourly + 7 daily + 4 weekly + 12 monthly            |
| Off-site Storage                      | Always copy to TrueNAS NFS + cloud storage             |
| Encryption                            | Encrypt backups at rest and in transit                 |
| Testing                               | Test restore procedure monthly                         |
| Documentation                         | Document restore steps, keep runbooks updated          |
| Monitoring                            | Alert on backup failures within 5 minutes              |
| Versioning                            | Keep multiple backup versions, never overwrite         |

---

## �📊 Monitoring Dashboards

### Prometheus Targets
- kubernetes-apiservers
- kubernetes-nodes
- kubernetes-nodes-cadvisor
- kubernetes-service-endpoints
- kubernetes-pods

### Recommended Grafana Dashboards
| **Dashboard Name**              | **Dashboard ID** | **Description**                     |
|---------------------------------|------------------|-------------------------------------|
| Kubernetes Cluster Monitoring   | 315              | Overall cluster health              |
| Node Exporter Full              | 1860             | Detailed node metrics               |
| Kubernetes Pods                 | 6417             | Pod-level metrics                   |
| Nginx Ingress Controller        | 9614             | Nginx-specific metrics              |

---

## 📝 Verification Checklist

### Cluster Health
- [ ] All nodes in Ready state: `kubectl get nodes`
- [ ] All system pods running: `kubectl get pods -n kube-system`
- [ ] CoreDNS functioning: `kubectl run test --image=busybox --rm -it --restart=Never -- nslookup kubernetes`
- [ ] Calico pods running: `kubectl get pods -n calico-system`

### Storage
- [ ] NFS mount accessible from nodes
- [ ] PV in Available/Bound state: `kubectl get pv`
- [ ] PVC in Bound state: `kubectl get pvc`
- [ ] Data persistence test passed

### Monitoring
- [ ] Prometheus accessible and scraping targets
- [ ] Grafana accessible with dashboards
- [ ] Metrics visible for nodes, pods, and containers

### Security
- [ ] Firewall rules active on all nodes
- [ ] Network policies enforced
- [ ] RBAC working as expected
- [ ] SSH key-based auth only
- [ ] Pod Security Standards enforced: `kubectl get ns --show-labels | grep pod-security`
- [ ] Falco DaemonSet running on all nodes: `kubectl get pods -n falco`
- [ ] Falco alerts visible: `kubectl logs -n falco -l app=falco`

### Application
- [ ] Nginx deployment running with 3 replicas
- [ ] Service accessible via NodePort
- [ ] Self-healing working (pod recreation)
- [ ] Workload rescheduling on node failure

---

## 🔧 Troubleshooting Guide

| **Issue**                           | **Diagnostic Command**                              | **Resolution**                                    |
|-------------------------------------|-----------------------------------------------------|---------------------------------------------------|
| Node NotReady                       | `kubectl describe node <name>`                      | Check kubelet logs, network connectivity          |
| Pod CrashLoopBackOff                | `kubectl logs <pod> --previous`                     | Fix application error, check resources            |
| PVC Pending                         | `kubectl describe pvc <name>`                       | Verify PV exists, check storage class             |
| NFS mount failed                    | `showmount -e <nfs-server>`                         | Check NFS exports, firewall, permissions          |
| Prometheus not scraping             | Check Prometheus targets page                       | Verify ServiceAccount, RBAC permissions           |
| Calico pods not starting            | `kubectl logs -n calico-system <pod>`               | Check IP pool configuration, node connectivity    |

---

## 📚 References

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Calico Documentation](https://docs.tigera.io/calico/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [TrueNAS Documentation](https://www.truenas.com/docs/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Falco Official Documentation](https://falco.org/docs/)
- [Falco Rules Repository](https://github.com/falcosecurity/rules)

---

## 👤 Project Information

| **Attribute**     | **Value**                                                    |
|-------------------|--------------------------------------------------------------|
| **Project Title** | Kubernetes Cluster Setup, Monitoring & Automation            |
| **Platform**      | DevOps                                                        |
| **Duration**      | 2 Months                                                      |
| **Institution**   | CDAC                                                          |

---

*Document Version: 1.0 | Last Updated: February 2026*

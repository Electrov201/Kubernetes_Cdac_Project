# Kubernetes Cluster Setup - 16GB+ RAM Configuration (Full Setup)

---

## 📋 Project Information

| **Attribute**       | **Details**                                                              |
|---------------------|--------------------------------------------------------------------------|
| **Platform**        | DevOps                                                                   |
| **Duration**        | 2 Months                                                                 |
| **Operating System**| Ubuntu Linux 22.04 LTS                                                   |
| **Orchestration**   | Kubernetes v1.29 (kubeadm)                                               |
| **Automation**      | Ansible 2.9+                                                             |
| **Storage**         | TrueNAS (NFS) with PV/PVC                                                |
| **Monitoring**      | Prometheus + Grafana                                                     |
| **Networking**      | Calico CNI                                                               |
| **Sample Workload** | Nginx Web Server                                                         |
| **Runtime Security**| Falco                                                                    |

---

## 💻 Hardware Requirements (16GB+ RAM - Full Setup)

| **Node**        | **vCPU** | **RAM**   | **Disk** | **Role**               |
|-----------------|----------|-----------|----------|------------------------|
| k8s-master      | 2        | 4 GB      | 50 GB    | Control Plane          |
| k8s-worker1     | 2        | 4 GB      | 50 GB    | Worker Node            |
| k8s-worker2     | 2        | 4 GB      | 50 GB    | Worker Node            |
| truenas         | 1        | 2 GB      | 100 GB   | NFS Storage            |
| **Total**       | **7**    | **14 GB** | **250 GB**|                       |

> 💡 **Note**: 16GB+ RAM allows for a full-featured production-like environment with all security and monitoring features enabled.

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
│    │    │  ┌─────────────┐  │       │       │  ┌─────────────┐  │        │      │
│    │    │  │   Falco     │  │       │       │  │   Falco     │  │        │      │
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
| Orchestration       | Kubernetes               | 1.29.x      | Container orchestration platform               |
| Cluster Bootstrap   | kubeadm                  | 1.29.x      | Cluster initialization and management          |
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
│   │   ├── security/                     # Security hardening
│   │   │   ├── tasks/
│   │   │   │   └── main.yml              # Firewall, SSH, CIS benchmarks
│   │   │   └── handlers/
│   │   │       └── main.yml              # SSH/Firewall restart handlers
│   │   │
│   │   └── etcd_backup/                  # etcd backup automation
│   │       ├── tasks/
│   │       │   └── main.yml              # Backup script deployment
│   │       └── templates/
│   │           └── etcd-backup.sh.j2     # Backup script template
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

## 📁 Ansible Configuration (16GB Setup)

### Inventory Configuration (hosts.ini)
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

### Global Variables (all.yml)
```yaml
# Kubernetes Configuration
kubernetes_version: "1.29"
pod_network_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"

# Container Runtime
container_runtime: "containerd"

# CNI - Use Calico for full setup
cni_plugin: "calico"

# TrueNAS NFS Storage
nfs_server: "192.168.1.100"
nfs_path: "/mnt/pool/kubernetes"
nfs_backup_path: "/mnt/pool/etcd-backups"

# Monitoring - Full settings
prometheus_nodeport: 30090
grafana_nodeport: 30300
prometheus_retention: "15d"

# Nginx - Full replicas
nginx_replicas: 3

# Falco - Enabled
falco_enabled: true
```

---

## 🔄 Implementation Workflow (16GB Setup)

### Phase 1: Infrastructure Preparation (Week 1-2)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Server Provisioning                   | Provision 4 Ubuntu 22.04 VMs (1 master, 2 workers, 1 TrueNAS)|
| Network Configuration                 | Configure static IPs, DNS resolution, host entries         |
| SSH Key Setup                         | Generate and distribute SSH keys for Ansible               |
| TrueNAS Configuration                 | Create NFS dataset and configure share                     |
| Ansible Control Node Setup            | Install Ansible on control machine                         |

### Phase 2: Kubernetes Cluster Deployment (Week 3-4)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Common Role Execution                 | Install containerd, kubelet, kubeadm, kubectl              |
| Master Node Initialization            | Run kubeadm init, install Calico CNI                       |
| Worker Node Join                      | Join workers using cluster token                           |
| Cluster Verification                  | Verify all nodes are in Ready state                        |

### Phase 3: Storage Integration (Week 5)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| NFS Mount Testing                     | Verify NFS connectivity from all nodes                     |
| PersistentVolume Creation             | Create PV pointing to TrueNAS NFS share                    |
| PersistentVolumeClaim Creation        | Create PVC for application storage                         |
| StorageClass Configuration            | Optional: Dynamic provisioning setup                       |

### Phase 4: Monitoring Stack Deployment (Week 6)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Prometheus Deployment                 | Deploy Prometheus with cluster-wide scraping               |
| Grafana Deployment                    | Deploy Grafana with Prometheus datasource                  |
| Dashboard Import                      | Import Kubernetes monitoring dashboards                    |
| Alert Rules Configuration             | Configure basic alerting rules                             |

### Phase 5: Security Hardening (Week 7)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| RBAC Configuration                    | Create roles, service accounts, role bindings              |
| Network Policies                      | Implement pod-to-pod communication restrictions            |
| CIS Benchmark Application             | Apply CIS Kubernetes security benchmarks                   |
| Firewall Rules                        | Configure UFW on all nodes                                 |
| SSH Hardening                         | Disable root login, enforce key-based auth                 |
| Falco Deployment                      | Deploy Falco DaemonSet for runtime security                |
| Pod Security Standards                | Apply PSS labels to namespaces                             |

### Phase 6: Application Deployment & Testing (Week 8)

| **Task**                              | **Description**                                            |
|---------------------------------------|-------------------------------------------------------------|
| Nginx Deployment                      | Deploy Nginx with 3 replicas                               |
| Self-Healing Testing                  | Delete pods and verify automatic recreation                |
| Storage Testing                       | Verify PVC mount and data persistence                      |
| Monitoring Validation                 | Verify metrics in Prometheus and Grafana                   |
| Load Testing                          | Basic load testing of the application                      |
| etcd Backup Setup                     | Configure automated etcd backup                            |

---

## 📋 Kubernetes Resources

### NFS PersistentVolume
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

### PersistentVolumeClaim
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

### Prometheus Deployment
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
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30090
```

### Grafana Deployment
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
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30300
```

### Nginx Deployment with Self-Healing
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
            - name: nginx-data
              mountPath: /usr/share/nginx/html
      volumes:
        - name: nginx-data
          persistentVolumeClaim:
            claimName: nfs-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: default
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

---

## 🔒 Security Implementation

### Network Policy Example
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

### RBAC Configuration
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

### Pod Security Standards
```yaml
# Apply Restricted PSS to default namespace
apiVersion: v1
kind: Namespace
metadata:
  name: default
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

### CIS Benchmark Checklist

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

## 🦅 Runtime Security with Falco

### Falco DaemonSet Deployment
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
        - name: falco-config
          configMap:
            name: falco-config
```

### Falco Custom Rules
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
```

---

## 💾 Backup & Disaster Recovery

### etcd Backup Script
```bash
#!/bin/bash
# ETCD Automated Backup Script for Kubernetes
set -euo pipefail

BACKUP_DIR="/backup/etcd"
NFS_BACKUP_DIR="/mnt/truenas/etcd-backups"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="etcd-snapshot-${DATE}.db"

export ETCDCTL_API=3
ENDPOINTS="https://127.0.0.1:2379"
CACERT="/etc/kubernetes/pki/etcd/ca.crt"
CERT="/etc/kubernetes/pki/etcd/server.crt"
KEY="/etc/kubernetes/pki/etcd/server.key"

mkdir -p "${BACKUP_DIR}"

etcdctl snapshot save "${BACKUP_DIR}/${BACKUP_NAME}" \
    --endpoints="${ENDPOINTS}" \
    --cacert="${CACERT}" \
    --cert="${CERT}" \
    --key="${KEY}"

# Copy to NFS
cp "${BACKUP_DIR}/${BACKUP_NAME}" "${NFS_BACKUP_DIR}/"

# Cleanup old backups (keep last 24 hours locally, 7 days on NFS)
find "${BACKUP_DIR}" -name "etcd-snapshot-*.db" -mmin +1440 -delete
find "${NFS_BACKUP_DIR}" -name "etcd-snapshot-*.db" -mtime +7 -delete
```

### Disaster Recovery Scenarios

| **Scenario**                          | **Recovery Action**                                    | **RTO**   |
|---------------------------------------|-------------------------------------------------------|-----------| 
| Single etcd member failure            | Rejoin or replace member                               | 15 min    |
| etcd data corruption                  | Restore from latest snapshot                           | 30 min    |
| Master node failure (hardware)        | Provision new node, restore etcd                       | 1-2 hours |
| Complete cluster loss                 | Restore etcd + reinstall workers                       | 2-4 hours |
| Accidental namespace/resource deletion| Restore from snapshot before deletion                  | 30 min    |

---

## 🔥 Firewall Rules (UFW)

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
| Grafana        | http://<node-ip>:30300       | 30300    | admin / admin       |
| Nginx          | http://<node-ip>:30080       | 30080    | N/A                 |

---

## 📊 Monitoring Dashboards

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

## 📝 Verification Checklist (16GB Setup)

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

### Backup
- [ ] etcd backup script running
- [ ] Backups stored on TrueNAS NFS
- [ ] Restore procedure tested

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
| Falco not detecting                 | `kubectl logs -n falco -l app=falco`                | Verify privileged mode, kernel access             |

---

## ✅ Features Enabled in 16GB Setup

| **Feature**              | **Status** | **Description**                                      |
|--------------------------|------------|------------------------------------------------------|
| Calico CNI               | ✅ Enabled | Full networking with NetworkPolicy support           |
| Falco Runtime Security   | ✅ Enabled | Real-time threat detection                           |
| TrueNAS NFS Storage      | ✅ Enabled | Persistent storage with PV/PVC                       |
| Multiple Worker Nodes    | ✅ Enabled | 2 worker nodes for HA                                |
| 3 Nginx Replicas         | ✅ Enabled | High availability for workloads                      |
| etcd Backup              | ✅ Enabled | Automated backup to NFS                              |
| Pod Security Standards   | ✅ Enabled | Namespace-level security enforcement                 |
| Network Policies         | ✅ Enabled | Pod-to-pod communication restrictions                |

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
| **Project Title** | Kubernetes Cluster Setup - 16GB+ Full Configuration          |
| **Platform**      | DevOps                                                        |
| **Duration**      | 2 Months                                                      |
| **Institution**   | CDAC                                                          |

---

*Document Version: 1.0 | Last Updated: February 2026*

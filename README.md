# Kubernetes Cluster Setup with Ansible Automation

A production-ready Kubernetes cluster setup with monitoring, security, and automation.

## 🚀 Quick Start

### Prerequisites

1. **Ubuntu 22.04 VMs** (Master + Worker nodes)
2. **Ansible installed** on your control machine
3. **SSH key access** to all VMs

### Setup Steps

```bash
# 1. Clone/Copy project to your Ansible control machine
cd "Cdac Project"

# 2. Update inventory with your VM IPs
nano ansible/inventory/hosts.ini

# 3. Update variables (NFS server, etc.)
nano ansible/group_vars/all.yml

# 4. Run the playbook
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

## 📁 Project Structure

```
Cdac Project/
├── ansible/
│   ├── inventory/hosts.ini     # Update with your VM IPs
│   ├── group_vars/all.yml      # Configuration variables
│   ├── site.yml                # Main playbook
│   └── roles/
│       ├── common/             # Prerequisites & containerd
│       ├── k8s_master/         # Control plane setup
│       ├── k8s_worker/         # Worker node join
│       └── security/           # Firewall & hardening
├── kubernetes/
│   ├── monitoring/             # Prometheus & Grafana
│   ├── storage/                # NFS PV/PVC
│   ├── nginx/                  # Sample workload
│   ├── security/               # Network Policies & RBAC
│   └── falco/                  # Runtime security (optional)
├── scripts/
│   └── etcd-backup.sh         # Automated backup script
└── docs/
    └── Kubernetes_Cluster_Project_Document.md
```

## 🔧 Configuration

Edit `ansible/group_vars/all.yml`:

| Variable | Description | Default |
|----------|-------------|---------|
| `api_server_advertise_address` | Master node IP | 192.168.1.10 |
| `nfs_server` | Ubuntu NFS Server IP | 192.168.1.100 |
| `cni_plugin` | flannel or calico | flannel |
| `enable_falco` | Enable runtime security | false |

## 🖥️ Access Services

After deployment:

| Service | URL | Credentials |
|---------|-----|-------------|
| Prometheus | http://<node-ip>:30090 | N/A |
| Grafana | http://<node-ip>:30300 | admin / admin |
| Nginx | http://<node-ip>:30080 | N/A |

## ✅ Verification

```bash
# Check nodes
kubectl get nodes

# Check pods
kubectl get pods --all-namespaces

# Test self-healing
kubectl delete pod <nginx-pod-name>
kubectl get pods -w
```

## 📚 Documentation

See [Kubernetes_Cluster_Project_Document.md](docs/Kubernetes_Cluster_Project_Document.md) for complete documentation.

## 📋 Features

- ✅ **Automation**: Ansible-based deployment
- ✅ **Monitoring**: Prometheus + Grafana
- ✅ **Security**: PSS, Network Policies, RBAC, Firewall
- ✅ **Storage**: Ubuntu NFS Server integration
- ✅ **Self-Healing**: Liveness/Readiness probes
- ✅ **Backup**: Automated etcd backup
- ✅ **Runtime Security**: Falco (optional)

## 📈 Scaling Capabilities

### Horizontal Scaling ↔️

| Component | Replicas | Scaling Support |
|-----------|----------|-----------------|
| Nginx | 2 | ✅ Manual (`kubectl scale deployment nginx --replicas=N`) |
| Prometheus | 1 | ⚠️ Single instance by design |
| Grafana | 1 | ⚠️ Requires shared storage for HA |
| Node Exporter | DaemonSet | ✅ Auto-scales with nodes |
| Falco | DaemonSet | ✅ Auto-scales with nodes |

**Note**: NFS storage uses `ReadWriteMany` access mode, enabling multiple pods to share storage.

### Vertical Scaling ↕️

- **Resource Limits**: Defined for all containers in `ansible/group_vars/all.yml`
- **VPA**: Not configured (can be added for automatic resource adjustment)

### Current Limitations

This project is optimized for **8GB RAM, 2-node lab environment**:
- No HPA (Horizontal Pod Autoscaler) configured
- No Metrics Server deployed
- No Cluster Autoscaler configured

### Adding Auto-Scaling

```bash
# Deploy Metrics Server (required for HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Scale Nginx manually
kubectl scale deployment nginx --replicas=5
```


# 🚀 Complete Step-by-Step Setup Guide

## Project Overview

This guide walks you through deploying a **production-ready Kubernetes cluster** from scratch using VirtualBox/VMware VMs.

---

## 📋 Project Structure Analysis

```
Cdac Project/
│
├── 📄 README.md                     # Quick start reference
│
├── 📁 ansible/                      # Automation scripts
│   ├── inventory/hosts.ini          # VM IP addresses (YOU MUST EDIT)
│   ├── group_vars/all.yml           # Cluster configuration (YOU MUST EDIT)
│   ├── site.yml                     # Main deployment playbook
│   └── roles/
│       ├── common/                  # Prerequisites: swap, containerd, K8s packages
│       ├── k8s_master/              # Cluster initialization, CNI, PSS
│       ├── k8s_worker/              # Worker node join
│       └── security/                # Firewall, SSH hardening
│
├── 📁 kubernetes/                   # K8s manifests (auto-deployed)
│   ├── monitoring/                  # Prometheus + Grafana
│   ├── storage/                     # NFS PV/PVC for Ubuntu NFS Server
│   ├── nginx/                       # Sample application
│   ├── security/                    # Network Policies, RBAC
│   └── falco/                       # Runtime security
│   ├── nginx/                       # Sample application
│   ├── security/                    # Network Policies, RBAC
│   └── falco/                       # Runtime security
│
├── 📁 scripts/
│   └── etcd-backup.sh              # Automated backup script
│
└── 📁 docs/
    ├── Kubernetes_Cluster_Project_Document.md  # Full documentation
    └── setup_guide.md              # THIS FILE
```

---

## 🖥️ VM Requirements

### Option 1: 8GB RAM Setup (3 VMs)
| VM Name | RAM | vCPU | Disk | Role |
|---------|-----|------|------|------|
| k8s-master | 3 GB | 2 | 30 GB | Control Plane + Workloads |
| k8s-worker1 | 3 GB | 2 | 30 GB | Worker Node |
| nfs-server | 2 GB | 1 | 50 GB | Ubuntu NFS Server |
| **Total** | **8 GB** | **5** | **110 GB** | |

### Option 2: 16GB RAM Setup (3 VMs + Storage)
| VM Name | RAM | vCPU | Disk | Role |
|---------|-----|------|------|------|
| k8s-master | 4 GB | 2 | 50 GB | Control Plane |
| k8s-worker1 | 4 GB | 2 | 50 GB | Worker Node |
| k8s-worker2 | 4 GB | 2 | 50 GB | Worker Node |
| nfs-server | 2 GB | 1 | 100 GB | Ubuntu NFS Server |
| **Total** | **14 GB** | **7** | **250 GB** | |

---

## 📝 Step-by-Step Instructions

### Phase 1: Create Virtual Machines (30 minutes)

#### Step 1.1: Download Ubuntu Server
```
Download: Ubuntu Server 22.04 LTS
URL: https://ubuntu.com/download/server
File: ubuntu-22.04.x-live-server-amd64.iso
```

#### Step 1.2: Create VMs in VirtualBox/VMware

**For each VM:**
1. Create new VM with Ubuntu 64-bit
2. Allocate RAM as per table above
3. Create virtual hard disk (VDI, dynamically allocated)
4. Configure network: **Bridged Adapter** (VMs must be on same network)
5. Boot from Ubuntu ISO and install

**Ubuntu Installation Options:**
- Hostname: `k8s-master` or `k8s-worker1`
- Username: `ubuntu`
- Enable OpenSSH Server: **Yes**
- No additional packages needed

#### Step 1.3: Note IP Addresses
After installation, get each VM's IP:
```bash
ip addr show | grep inet
```
Write down:
- k8s-master IP: _______________
- k8s-worker1 IP: _______________
- nfs-server IP: _______________

---

### Phase 1.5: Setup NFS Server (15 minutes)

**SSH to the nfs-server VM:**
```bash
ssh ubuntu@<nfs-server-ip>
```

**Install NFS Server:**
```bash
# Update and install NFS
sudo apt update
sudo apt install -y nfs-kernel-server

# Create NFS directories
sudo mkdir -p /srv/nfs/kubernetes/{prometheus,grafana,nginx}
sudo mkdir -p /srv/nfs/etcd-backups

# Set permissions (allow K8s nodes to write)
sudo chown -R nobody:nogroup /srv/nfs
sudo chmod -R 777 /srv/nfs

# Configure NFS exports
sudo tee /etc/exports << 'EOF'
/srv/nfs/kubernetes  *(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/etcd-backups  *(rw,sync,no_subtree_check,no_root_squash)
EOF

# Apply exports and restart NFS
sudo exportfs -rav
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# Verify exports
showmount -e localhost
```

**Expected output:**
```
Export list for localhost:
/srv/nfs/etcd-backups  *
/srv/nfs/kubernetes    *
```

### Phase 2: Prepare Control Machine (15 minutes)

Your **control machine** is where you run Ansible (can be your Windows PC with WSL, or one of the VMs).

#### Step 2.1: Install Ansible

**On Ubuntu/WSL:**
```bash
sudo apt update
sudo apt install -y ansible python3-pip sshpass
ansible --version
```

**On Windows (PowerShell):**
```powershell
# Use WSL or install Ubuntu from Microsoft Store
wsl --install -d Ubuntu
# Then follow Ubuntu steps above
```

#### Step 2.2: Generate SSH Keys
```bash
# Generate SSH key (press Enter for all prompts)
ssh-keygen -t rsa -b 4096

# Copy key to each VM (enter password when prompted)
ssh-copy-id ubuntu@<k8s-master-ip>
ssh-copy-id ubuntu@<k8s-worker1-ip>

# Test SSH access (should not ask for password)
ssh ubuntu@<k8s-master-ip> "hostname"
ssh ubuntu@<k8s-worker1-ip> "hostname"
```

---

### Phase 3: Configure the Project (10 minutes)

#### Step 3.1: Copy Project to Control Machine
```bash
# If project is on Windows, copy to WSL
cp -r "/mnt/d/Cdac Project" ~/k8s-project
cd ~/k8s-project
```

#### Step 3.2: Edit Inventory File ⚠️ REQUIRED
```bash
nano ansible/inventory/hosts.ini
```

**Update with YOUR VM IPs:**
```ini
[masters]
k8s-master ansible_host=192.168.144.130    # ← Your master IP

[workers]
k8s-worker1 ansible_host=192.168.144.134   # ← Your worker IP

[k8s_cluster:children]
masters
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
ansible_become=true
```

#### Step 3.3: Edit Variables File (Optional)
```bash
nano ansible/group_vars/all.yml
```

**Key settings to verify:**
```yaml
# Update with your master IP
api_server_advertise_address: "192.168.144.130

# Update with your NFS server IP:
nfs_server: "192.168.144.132"
nfs_path: "/srv/nfs/kubernetes"

# CNI choice (flannel is lighter)
cni_plugin: "flannel"

# Security features
enable_falco: true
enable_pod_security_standards: true
```

---

### Phase 4: Deploy the Cluster (20-30 minutes)

#### Step 4.1: Test Ansible Connection
```bash
cd ~/k8s-project/ansible

# Ping all VMs
ansible -i inventory/hosts.ini all -m ping
```

**Expected output:**
```
k8s-master | SUCCESS => {"ping": "pong"}
k8s-worker1 | SUCCESS => {"ping": "pong"}
```

#### Step 4.2: Run the Playbook
```bash
# Deploy everything!
ansible-playbook -i inventory/hosts.ini site.yml
```

**What happens:**
1. ✅ Disables swap on all nodes
2. ✅ Installs containerd runtime
3. ✅ Installs kubeadm, kubelet, kubectl
4. ✅ Initializes Kubernetes cluster
5. ✅ Installs Flannel CNI
6. ✅ Joins worker nodes
7. ✅ Deploys Prometheus & Grafana
8. ✅ Deploys Nginx sample app
9. ✅ Configures security (firewall, PSS)
10. ✅ Deploys Falco runtime security

**Wait for completion (15-25 minutes)**

---

### Phase 5: Verify Deployment (5 minutes)

#### Step 5.1: SSH to Master Node
```bash
ssh ubuntu@<k8s-master-ip>
```

#### Step 5.2: Check Cluster Status
```bash
# View nodes
kubectl get nodes

# Expected output:
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   10m   v1.29.x
k8s-worker1   Ready    <none>          8m    v1.29.x
```

#### Step 5.3: Check All Pods
```bash
kubectl get pods --all-namespaces

# Expected: All pods should be Running or Completed
```

#### Step 5.4: Check Services
```bash
kubectl get svc --all-namespaces
```

---

### Phase 6: Access Services

Open in your browser:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Prometheus** | http://\<master-ip\>:30090 | N/A |
| **Grafana** | http://\<master-ip\>:30300 | admin / admin |
| **Nginx** | http://\<master-ip\>:30080 | N/A |

---

## 🧪 Testing Features

### Test 1: Self-Healing
```bash
# Delete a pod
kubectl delete pod $(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')

# Watch it recreate automatically
kubectl get pods -l app=nginx -w
```

### Test 2: Falco Detection
```bash
# Exec into a container (triggers Falco alert)
kubectl exec -it $(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}') -- sh

# Check Falco logs
kubectl logs -n falco -l app=falco --tail=20
```

### Test 3: Node Failure
```bash
# Cordon a node
kubectl cordon k8s-worker1

# Drain pods
kubectl drain k8s-worker1 --ignore-daemonsets --delete-emptydir-data

# Observe pods rescheduled
kubectl get pods -o wide

# Uncordon when done
kubectl uncordon k8s-worker1
```

---

## 🔧 Troubleshooting

### Issue: Ansible ping fails
```bash
# Check SSH connectivity
ssh -v ubuntu@<ip>

# Ensure SSH key is copied
ssh-copy-id ubuntu@<ip>
```

### Issue: Nodes not Ready
```bash
# Check kubelet status
sudo systemctl status kubelet

# Check logs
sudo journalctl -xeu kubelet
```

### Issue: Pods stuck in Pending
```bash
# Describe pod for errors
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Issue: CNI not working
```bash
# Check Flannel pods
kubectl get pods -n kube-flannel

# Reapply CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

---

## 📊 File-by-File Explanation

### Ansible Files

| File | Purpose |
|------|---------|
| `hosts.ini` | Lists your VM IP addresses |
| `all.yml` | All configurable settings |
| `site.yml` | Main playbook that runs everything |
| `common/tasks/main.yml` | Installs prerequisites, containerd, K8s |
| `k8s_master/tasks/main.yml` | Initializes cluster, installs CNI |
| `k8s_worker/tasks/main.yml` | Joins workers to cluster |
| `security/tasks/main.yml` | Configures firewall, SSH |

### Kubernetes Manifests

| File | Purpose |
|------|---------|
| `monitoring/namespace.yaml` | Creates monitoring namespace |
| `monitoring/prometheus.yaml` | Deploys Prometheus with RBAC |
| `monitoring/grafana.yaml` | Deploys Grafana with datasource |
| `storage/nfs-pv.yaml` | NFS storage volume |
| `storage/nfs-pvc.yaml` | Storage claim for apps |
| `nginx/deployment.yaml` | Sample app with self-healing |
| `security/network-policy.yaml` | Network isolation rules |
| `security/pss-rbac.yaml` | Pod Security Standards + RBAC |
| `falco/falco.yaml` | Runtime security DaemonSet |

### Scripts

| File | Purpose |
|------|---------|
| `etcd-backup.sh` | Backs up etcd database hourly |

---

## ✅ Deployment Checklist

- [ ] Created 3 Ubuntu VMs (3GB master, 3GB worker, 2GB NFS)
- [ ] VMs are on same network (bridged adapter)
- [ ] Installed Ansible on control machine
- [ ] SSH keys copied to all VMs
- [ ] Updated `hosts.ini` with VM IPs
- [ ] Updated `all.yml` with master IP
- [ ] Ran `ansible all -m ping` successfully
- [ ] Ran `ansible-playbook site.yml` successfully
- [ ] All nodes show `Ready` status
- [ ] All pods are `Running`
- [ ] Accessed Prometheus, Grafana, Nginx

---

## 🎓 For CDAC Demo

**Recommended demo flow:**
1. Show cluster status: `kubectl get nodes`
2. Show running pods: `kubectl get pods -A`
3. Open Grafana dashboard
4. Demo self-healing: delete a pod, show recreation
5. Demo Falco: exec into container, show alert
6. Show etcd backup: `ls /backup/etcd/`

**Total setup time: ~1.5 hours**

---

## 📞 Support

If you encounter issues:
1. Check troubleshooting section above
2. Review Ansible logs for errors
3. Check `kubectl describe` for pod issues

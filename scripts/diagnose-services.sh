#!/bin/bash
# =============================================================================
# Diagnostic Script for Prometheus, Grafana, and Nginx Services
# =============================================================================
# Run this script on your Kubernetes master node
# =============================================================================

set -e

echo "=================================================="
echo "Kubernetes Services Diagnostic Report"
echo "=================================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
echo "1. Checking Kubernetes Cluster Status..."
echo "-------------------------------------------"
kubectl cluster-info || { echo "ERROR: Cannot connect to cluster"; exit 1; }
echo ""

# Check nodes
echo "2. Node Status:"
echo "-------------------------------------------"
kubectl get nodes -o wide
echo ""

# Check namespaces
echo "3. Checking Namespaces..."
echo "-------------------------------------------"
kubectl get namespaces
if ! kubectl get namespace monitoring &> /dev/null; then
    echo ""
    echo "WARNING: 'monitoring' namespace does not exist!"
    echo "FIX: Run 'kubectl create namespace monitoring' or apply namespace.yaml"
fi
echo ""

# Check PersistentVolumes
echo "4. PersistentVolumes Status:"
echo "-------------------------------------------"
kubectl get pv -o wide
echo ""

# Check PersistentVolumeClaims
echo "5. PersistentVolumeClaims Status:"
echo "-------------------------------------------"
kubectl get pvc --all-namespaces
echo ""

# Check if PVCs are bound
echo "6. Checking PVC Binding Status..."
echo "-------------------------------------------"
PENDING_PVCS=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | grep -v "Bound" || true)
if [ -n "$PENDING_PVCS" ]; then
    echo "WARNING: The following PVCs are NOT bound:"
    echo "$PENDING_PVCS"
    echo ""
    echo "FIX: Check NFS server connectivity and ensure NFS paths exist"
else
    echo "All PVCs are bound (or no PVCs exist)"
fi
echo ""

# Check Deployments
echo "7. Deployment Status:"
echo "-------------------------------------------"
kubectl get deployments --all-namespaces -l 'app in (prometheus,grafana,nginx)' -o wide
echo ""

# Check Pods
echo "8. Pod Status (All Services):"
echo "-------------------------------------------"
kubectl get pods --all-namespaces -o wide | grep -E "(prometheus|grafana|nginx|NAME)"
echo ""

# Check for pending/crashed pods
echo "9. Checking for Pod Issues..."
echo "-------------------------------------------"
PROBLEM_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -vE "Running|Completed" | grep -E "(prometheus|grafana|nginx)" || true)
if [ -n "$PROBLEM_PODS" ]; then
    echo "WARNING: The following pods have issues:"
    echo "$PROBLEM_PODS"
    echo ""
    echo "Checking pod details..."
    
    # Get details of problematic pods
    for NS_POD in $(echo "$PROBLEM_PODS" | awk '{print $1"/"$2}'); do
        NS=$(echo $NS_POD | cut -d'/' -f1)
        POD=$(echo $NS_POD | cut -d'/' -f2)
        echo ""
        echo "--- Pod: $POD (Namespace: $NS) ---"
        kubectl describe pod -n "$NS" "$POD" | tail -20
    done
else
    echo "All service pods are running"
fi
echo ""

# Check Services
echo "10. Service Status:"
echo "-------------------------------------------"
kubectl get svc --all-namespaces | grep -E "(prometheus|grafana|nginx|NAME)"
echo ""

# Check NodePorts accessibility
echo "11. NodePort Information:"
echo "-------------------------------------------"
MASTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Master Node IP: $MASTER_IP"
echo ""
echo "Access URLs:"
echo "  - Prometheus: http://$MASTER_IP:30090"
echo "  - Grafana:    http://$MASTER_IP:30300  (admin/admin)"
echo "  - Nginx:      http://$MASTER_IP:30080"
echo ""

# Check firewall status
echo "12. Checking Firewall (if ufw is installed)..."
echo "-------------------------------------------"
if command -v ufw &> /dev/null; then
    ufw status 2>/dev/null || echo "Could not check ufw status"
else
    echo "ufw not installed (may be using other firewall)"
fi
echo ""

# Check endpoints
echo "13. Service Endpoints:"
echo "-------------------------------------------"
echo "Prometheus Endpoints:"
kubectl get endpoints prometheus -n monitoring 2>/dev/null || echo "  Not found"
echo ""
echo "Grafana Endpoints:"
kubectl get endpoints grafana -n monitoring 2>/dev/null || echo "  Not found"
echo ""
echo "Nginx Endpoints:"
kubectl get endpoints nginx -n default 2>/dev/null || echo "  Not found"
echo ""

# Summary and recommendations
echo "=================================================="
echo "DIAGNOSTIC SUMMARY"
echo "=================================================="
echo ""

# Check NFS connectivity
echo "14. NFS Server Connectivity Test:"
echo "-------------------------------------------"
NFS_SERVER="192.168.144.132"
if ping -c 1 -W 2 $NFS_SERVER &> /dev/null; then
    echo "NFS Server ($NFS_SERVER) is reachable"
else
    echo "WARNING: Cannot ping NFS Server ($NFS_SERVER)"
    echo "FIX: Check network connectivity and firewall rules"
fi

# Check if NFS is mounted
if command -v showmount &> /dev/null; then
    echo ""
    echo "NFS Exports from $NFS_SERVER:"
    showmount -e $NFS_SERVER 2>/dev/null || echo "  Could not query NFS exports"
fi
echo ""

echo "=================================================="
echo "QUICK FIX COMMANDS"
echo "=================================================="
echo ""
echo "If services are not deployed, run these in order:"
echo ""
echo "1. Create monitoring namespace:"
echo "   kubectl apply -f /path/to/monitoring/namespace.yaml"
echo ""
echo "2. Apply storage (PVs and PVCs):"
echo "   kubectl apply -f /path/to/storage/nfs-pv.yaml"
echo "   kubectl apply -f /path/to/storage/nfs-pvc.yaml"
echo ""
echo "3. Deploy monitoring stack:"
echo "   kubectl apply -f /path/to/monitoring/prometheus.yaml"
echo "   kubectl apply -f /path/to/monitoring/grafana.yaml"
echo ""
echo "4. Deploy nginx:"
echo "   kubectl apply -f /path/to/nginx/deployment.yaml"
echo ""
echo "5. Check pod logs if issues persist:"
echo "   kubectl logs -n monitoring deployment/prometheus"
echo "   kubectl logs -n monitoring deployment/grafana"
echo "   kubectl logs deployment/nginx"
echo ""

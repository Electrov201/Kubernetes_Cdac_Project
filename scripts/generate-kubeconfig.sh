#!/bin/bash
# =============================================================================
# Kubeconfig Generator for ServiceAccounts
# =============================================================================
# This script extracts a ServiceAccount and generates a completely standalone 
# and portable .kubeconfig file using the K8s 1.24+ TokenRequest API.
# Token expires in 24 hours.
# =============================================================================

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <service-account-name> [namespace]"
    echo "Example: $0 developer default"
    exit 1
fi

SA_NAME=$1
NAMESPACE=${2:-default}
EXPIRATION="24h"

echo "Generating kubeconfig for ServiceAccount '$SA_NAME' in namespace '$NAMESPACE'..."
echo "Token will expire in $EXPIRATION."

# 1. Check if SA exists
if ! kubectl get sa $SA_NAME -n $NAMESPACE &> /dev/null; then
    echo "ERROR: ServiceAccount '$SA_NAME' not found in namespace '$NAMESPACE'."
    exit 1
fi

# 2. Get cluster info
SERVER=$(kubectl config view --minify --output jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(kubectl config view --minify --output jsonpath='{.clusters[0].name}')
CA_DATA=$(kubectl config view --raw --minify --output jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# 3. Create Token (Requires K8s 1.24+)
echo "Requesting Token API for access..."
TOKEN=$(kubectl create token $SA_NAME -n $NAMESPACE --duration=$EXPIRATION)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to generate token. Are you running this on the master node?"
    exit 1
fi

# 4. Generate the kubeconfig text
KUBECONFIG_FILE="${SA_NAME}-${NAMESPACE}.kubeconfig"

cat <<EOF > $KUBECONFIG_FILE
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    certificate-authority-data: ${CA_DATA}
    server: ${SERVER}
contexts:
- name: ${SA_NAME}-${CLUSTER_NAME}-context
  context:
    cluster: ${CLUSTER_NAME}
    namespace: ${NAMESPACE}
    user: ${SA_NAME}
current-context: ${SA_NAME}-${CLUSTER_NAME}-context
users:
- name: ${SA_NAME}
  user:
    token: ${TOKEN}
EOF

echo "============================================================"
echo "✅ SUCCESS! Generated: $KUBECONFIG_FILE"
echo "============================================================"
echo "To test access locally (remember it expires in 24h):"
echo "export KUBECONFIG=./$KUBECONFIG_FILE"
echo "kubectl get pods"
echo "============================================================"

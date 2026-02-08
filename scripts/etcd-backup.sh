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

# Check if etcdctl is available
if ! command -v etcdctl &> /dev/null; then
    log "ERROR: etcdctl not found. Please install etcd-client."
    exit 1
fi

# Take snapshot
if etcdctl snapshot save "${BACKUP_DIR}/${BACKUP_NAME}" \
    --endpoints="${ENDPOINTS}" \
    --cacert="${CACERT}" \
    --cert="${CERT}" \
    --key="${KEY}"; then
    log "Snapshot created: ${BACKUP_NAME}"
else
    log "ERROR: Failed to create snapshot!"
    exit 1
fi

# Verify snapshot
if etcdctl snapshot status "${BACKUP_DIR}/${BACKUP_NAME}" --write-out=table; then
    log "Snapshot verified: ${BACKUP_NAME}"
else
    log "ERROR: Snapshot verification failed!"
    exit 1
fi

# Copy to NFS (TrueNAS) if available
if [ -d "${NFS_BACKUP_DIR}" ]; then
    if cp "${BACKUP_DIR}/${BACKUP_NAME}" "${NFS_BACKUP_DIR}/"; then
        log "Backup copied to NFS: ${NFS_BACKUP_DIR}/${BACKUP_NAME}"
    else
        log "WARNING: Failed to copy backup to NFS"
    fi
else
    log "NFS backup directory not available, skipping remote copy"
fi

# Cleanup old backups (keep last 24 hourly backups locally)
log "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "etcd-snapshot-*.db" -mmin +$((RETENTION_HOURS * 60)) -delete 2>/dev/null || true

# Cleanup NFS backups (keep last 7 days)
if [ -d "${NFS_BACKUP_DIR}" ]; then
    find "${NFS_BACKUP_DIR}" -name "etcd-snapshot-*.db" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
fi

log "Backup completed successfully: ${BACKUP_NAME}"

# Print backup statistics
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}" | cut -f1)
TOTAL_BACKUPS=$(find "${BACKUP_DIR}" -name "etcd-snapshot-*.db" | wc -l)
log "Backup size: ${BACKUP_SIZE}, Total local backups: ${TOTAL_BACKUPS}"

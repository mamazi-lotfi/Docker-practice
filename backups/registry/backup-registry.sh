#!/bin/bash

set -e

SOURCE_DIR="/home/zhinoadmin/train/Docker/registry-setup"
BACKUP_DIR="/home/zhinoadmin/train/Docker/backups/registry"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="registry_backup_${TIMESTAMP}.tar.gz"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" \
    -C "$SOURCE_DIR" data auth

echo "Backup created: ${BACKUP_DIR}/${BACKUP_FILE}"

find "$BACKUP_DIR" -name "registry_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "Old backups cleaned (older than ${RETENTION_DAYS} days)"
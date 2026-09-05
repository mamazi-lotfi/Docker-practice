#!/bin/bash

set -e

BACKUP_DIR="/home/zhinoadmin/train/Docker/backups/registry/wordpress-db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="wp_db_backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=7

ENV_FILE="/home/zhinoadmin/train/Docker/registry-setup/.env"
MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD "$ENV_FILE" | cut -d= -f2)
MYSQL_DATABASE=$(grep MYSQL_DATABASE "$ENV_FILE" | cut -d= -f2)

mkdir -p "$BACKUP_DIR"

docker exec wp-db sh -c "mysqldump -u root -p'${MYSQL_ROOT_PASSWORD}' ${MYSQL_DATABASE}" | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

echo "Backup created: ${BACKUP_DIR}/${BACKUP_FILE}"

find "$BACKUP_DIR" -name "wp_db_backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

echo "Old backups cleaned (older than ${RETENTION_DAYS} days)"
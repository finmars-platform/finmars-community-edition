#!/bin/bash

# Script to download/backup the storage volume
# Usage: ./scripts/download-storage.sh [backup_name]

set -e

timestamp=${1:-$(date +%Y%m%d%H%M%S)}

BACKUP_NAME="storage"
BACKUP_DIR="./dumps/${timestamp}"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
VOLUME_NAME="finmars-community-edition_storage"

echo "Starting storage volume backup..."
echo "Volume: ${VOLUME_NAME}"
echo "Output: ${BACKUP_FILE}"

mkdir -p "${BACKUP_DIR}"

echo "Creating backup archive..."

if docker ps --format '{{.Names}}' | grep -q "finmars-community-edition-core-1"; then
    docker exec finmars-community-edition-core-1 tar czf /tmp/storage_backup.tar.gz -C /var/app/finmars_data .
    docker cp finmars-community-edition-core-1:/tmp/storage_backup.tar.gz "${BACKUP_FILE}"
    docker exec finmars-community-edition-core-1 rm /tmp/storage_backup.tar.gz
    echo "✓ Backup created using running container"
else
    echo "Running container not found, using temporary container..."
    docker run --rm \
        -v "${VOLUME_NAME}:/data" \
        -v "${BACKUP_DIR}:/backup" \
        alpine \
        tar czf "/backup/${BACKUP_NAME}.tar.gz" -C /data .
fi

if [ -f "${BACKUP_FILE}" ]; then
    SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo "✓ Backup completed successfully!"
    echo "  File: ${BACKUP_FILE}"
    echo "  Size: ${SIZE}"
else
    echo "✗ Backup failed!"
    exit 1
fi

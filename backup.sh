#!/bin/bash

# OpenProject Backup Script
# This script creates a backup of OpenProject data and database

set -e

# Configuration
BACKUP_DIR="/var/backups/openproject"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openproject_backup_${DATE}"

# Create backup directory if it doesn't exist
sudo mkdir -p "$BACKUP_DIR"

echo "Starting OpenProject backup at $(date)"

# Stop the application (optional, for consistent backup)
echo "Stopping OpenProject services..."
docker-compose -f docker-compose.simple.yml stop web worker cron

# Create database backup
echo "Creating database backup..."
docker-compose -f docker-compose.simple.yml exec -T db pg_dump -U postgres openproject | gzip > "$BACKUP_DIR/${BACKUP_NAME}_database.sql.gz"

# Create assets backup
echo "Creating assets backup..."
docker run --rm -v openproject_opdata:/data -v "$BACKUP_DIR":/backup ubuntu tar czf "/backup/${BACKUP_NAME}_assets.tar.gz" -C /data .

# Restart the application
echo "Restarting OpenProject services..."
docker-compose -f docker-compose.simple.yml start web worker cron

# Create a backup manifest
echo "Creating backup manifest..."
cat > "$BACKUP_DIR/${BACKUP_NAME}_manifest.txt" << EOF
OpenProject Backup Information
==============================
Backup Date: $(date)
Backup Name: $BACKUP_NAME

Files:
- ${BACKUP_NAME}_database.sql.gz (PostgreSQL database dump)
- ${BACKUP_NAME}_assets.tar.gz (OpenProject assets and attachments)
- ${BACKUP_NAME}_manifest.txt (this file)

Restore Instructions:
1. Stop OpenProject: docker-compose down
2. Restore database: gunzip -c ${BACKUP_NAME}_database.sql.gz | docker-compose exec -T db psql -U postgres -d openproject
3. Restore assets: docker run --rm -v openproject_opdata:/data -v "$BACKUP_DIR":/backup ubuntu tar xzf "/backup/${BACKUP_NAME}_assets.tar.gz" -C /data
4. Start OpenProject: docker-compose up -d

EOF

echo "Backup completed successfully!"
echo "Backup location: $BACKUP_DIR"
echo "Database backup: ${BACKUP_NAME}_database.sql.gz"
echo "Assets backup: ${BACKUP_NAME}_assets.tar.gz"

# Optional: Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "openproject_backup_*" -mtime +7 -delete 2>/dev/null || true

echo "Backup process finished at $(date)"

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/../../data/backups/postgres"
ENV_FILE="$SCRIPT_DIR/../../secret/postgres/.env"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

set -a
source "$ENV_FILE"
set +a

mkdir -p "$BACKUP_DIR"

docker exec postgres pg_dumpall -U "$POSTGRES_USER" | gzip > "$BACKUP_DIR/postgres_$TIMESTAMP.sql.gz"

find "$BACKUP_DIR" -name "postgres_*.sql.gz" -mtime +7 -delete

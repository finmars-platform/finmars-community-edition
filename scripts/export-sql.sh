#!/bin/bash
set -e

set -o allexport
source .env
set +o allexport

timestamp=${1:-$(date +%Y%m%d%H%M%S)}

for SERVICE_NAME in core workflow; do
  DB_NAME="${SERVICE_NAME}_realm00000"
  DUMP_FILE="${SERVICE_NAME}.sql"
  mkdir -p dumps/${timestamp}

  echo "📤 Exporting database '$DB_NAME' to '$DUMP_FILE'..."
  docker exec $(docker compose ps -q db) pg_dump -U ${DB_USER} -d ${DB_NAME} > "dumps/${timestamp}/${DUMP_FILE}"
  echo "✅ Exported '$DB_NAME' to '$DUMP_FILE'."
done

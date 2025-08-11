#!/bin/bash
set -e

set -o allexport
source .env
set +o allexport

echo "🚀 Starting PostgreSQL container..."
docker compose up -d db

sleep 5

echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec $(docker compose ps -q db) pg_isready -U ${DB_USER} > /dev/null 2>&1; do
  sleep 1
done

echo "✅ PostgreSQL is ready."

for SERVICE_NAME in core workflow; do
  DB_NAME="${SERVICE_NAME}_realm00000"
  DUMP_FILE="${SERVICE_NAME}.sql"
  
  echo "📤 Exporting database '$DB_NAME' to '$DUMP_FILE'..."
  docker exec $(docker compose ps -q db) pg_dump -U ${DB_USER} -d ${DB_NAME} > "${DUMP_FILE}"
  echo "✅ Exported '$DB_NAME' to '$DUMP_FILE'."
done

docker compose down
echo "✅ Done!"

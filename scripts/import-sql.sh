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

echo "📦 Creating databases..."
for DB_NAME in core_realm00000 workflow_realm00000; do
  echo "🔍 Checking if database '$DB_NAME' exists..."
  if docker exec -i $(docker compose ps -q db) psql -U ${DB_USER} -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
    echo "✅ Database '$DB_NAME' already exists."
  else
    echo "➕ Creating database '$DB_NAME'..."
    docker exec -i $(docker compose ps -q db) psql -U ${DB_USER} -c "CREATE DATABASE $DB_NAME;"
  fi
done

for SERVICE_NAME in core workflow; do
  echo "🚚 Importing from data from dumps for $SERVICE_NAME..."
	docker exec -i finmars-community-edition-db-1 psql -U ${DB_USER} -d ${SERVICE_NAME}_realm00000 < ./${SERVICE_NAME}.sql
done

docker compose down
echo "✅ Done!"

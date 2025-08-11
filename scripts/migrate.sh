#!/bin/bash
set -e

set -o allexport
source .env
set +o allexport

echo "✅ Create storage folder"
mkdir -p ./storage 
sudo chmod 777 ./storage

echo "🚀 Starting Redis container..."
docker compose up -d redis

echo "🚀 Starting PostgreSQL container..."
docker compose up -d db

sleep 5

echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec $(docker compose ps -q db) pg_isready -U ${DB_USER} > /dev/null 2>&1; do
  sleep 5
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

  echo "🔍 Checking if schema '$BASE_API_URL' exists in '$DB_NAME'..."
  if docker exec -i $(docker compose ps -q db) psql -U ${DB_USER} -d "$DB_NAME" -tAc "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '$BASE_API_URL';" | grep -q "$BASE_API_URL"; then
    echo "✅ Schema '$BASE_API_URL' already exists in '$DB_NAME'."
  else
    echo "➕ Creating schema '$BASE_API_URL' in '$DB_NAME'..."
    docker exec -i $(docker compose ps -q db) psql -U ${DB_USER} -d "$DB_NAME" -c "CREATE SCHEMA $BASE_API_URL;"
  fi

done

echo "🚚 Running migrations core"
docker compose run --build --rm core-migration 

echo "🚚 Running migrations workflow"
docker compose run --build --rm workflow-migration

docker compose down
echo "✅ Done!"

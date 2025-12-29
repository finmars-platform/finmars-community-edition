#!/bin/bash
set -e

set -o allexport
source .env
set +o allexport

wait_for_keycloak() {
  echo "Waiting for Keycloak to be ready..."
  local timeout=300
  local elapsed=0
  
  while [ $elapsed -lt $timeout ]; do
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' $(docker compose ps -q keycloak) 2>/dev/null || echo "unknown")
    
    if [ "$health_status" = "healthy" ]; then
      echo "Keycloak is ready!"
      return 0
    elif [ "$health_status" = "unhealthy" ]; then
      echo "❌ Keycloak is unhealthy! Exiting with error."
      exit 1
    fi
    
    echo "Keycloak health status: $health_status (elapsed: ${elapsed}s)"
    sleep 10
    elapsed=$((elapsed + 10))
  done
  
  echo "❌ Timeout waiting for Keycloak to become healthy. Exiting with error."
  exit 1
}

echo "🚀 Starting Keycloak PostgreSQL container..."
docker compose up -d db_keycloak

echo "🚀 Starting Keycloak container..."
docker compose up -d keycloak 

echo "⏳ Waiting for Keycloak to be ready..."
wait_for_keycloak

echo "➕ Creating initial admin user in Keycloak realm finmars..."
./scripts/add-keycloak-user.sh --username "$ADMIN_USERNAME" --password "$ADMIN_PASSWORD"

docker compose down
echo "✅ Done!"

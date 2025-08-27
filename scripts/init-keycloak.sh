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

echo "✅ Configuring admin credentials..."
docker exec $(docker compose ps -q keycloak) /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user "$ADMIN_USERNAME" \
  --password "$ADMIN_PASSWORD"

echo "➕ Creating user $ADMIN_USERNAME..."
docker exec $(docker compose ps -q keycloak) /opt/keycloak/bin/kcadm.sh create users \
  -r "finmars" \
  -s username="$ADMIN_USERNAME" \
  -s enabled=true \

echo "➕ Setting password for user $ADMIN_USERNAME..."
docker exec $(docker compose ps -q keycloak) /opt/keycloak/bin/kcadm.sh set-password \
  -r "finmars" \
  --username "$ADMIN_USERNAME" \
  --new-password "$ADMIN_PASSWORD"

docker compose down
echo "✅ Done!"

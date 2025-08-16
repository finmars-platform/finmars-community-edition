#!/bin/bash
set -e

set -o allexport
source .env
set +o allexport

wait_for_keycloak() {
  echo "Waiting for Keycloak to be ready..."
  while [ "$(docker inspect --format='{{.State.Health.Status}}' $(docker compose ps -q keycloak))" != "healthy" ]; do
    echo "Keycloak health status: $(docker inspect --format='{{.State.Health.Status}}' $(docker compose ps -q keycloak))"
    sleep 5
  done
  echo "Keycloak is ready!"
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

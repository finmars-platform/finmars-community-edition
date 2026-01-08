#!/bin/bash
set -e

REALM="finmars"

set -o allexport
source .env
set +o allexport

>&2 echo "✅ Configuring admin credentials..."
docker exec "$(docker compose ps -q keycloak)" /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user "$ADMIN_USERNAME" \
  --password "$ADMIN_PASSWORD"

>&2 echo "📋 Fetching users from realm '$REALM'..."
# This prints JSON array of users to STDOUT
docker exec "$(docker compose ps -q keycloak)" /opt/keycloak/bin/kcadm.sh get users -r "$REALM"

>&2 echo "✅ Done."


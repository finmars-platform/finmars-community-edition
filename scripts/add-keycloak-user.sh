#!/bin/bash
set -e

USERNAME=""
PASSWORD=""
REALM="finmars"

print_usage() {
  echo "Usage:"
  echo "  $0 --username <username> --password <password>"
  echo "  $0 <username> <password>  # positional args also supported"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --username)
      USERNAME="$2"
      shift 2
      ;;
    --password)
      PASSWORD="$2"
      shift 2
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      # Treat remaining args as positional username/password if not set yet
      if [ -z "$USERNAME" ]; then
        USERNAME="$1"
      elif [ -z "$PASSWORD" ]; then
        PASSWORD="$1"
      else
        echo "Unknown or extra argument: $1"
        print_usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Error: username and password are required."
  print_usage
  exit 1
fi

set -o allexport
source .env
set +o allexport

echo "✅ Configuring admin credentials..."
docker exec $(docker compose ps -q keycloak) /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user "$ADMIN_USERNAME" \
  --password "$ADMIN_PASSWORD"

echo "➕ Creating user $USERNAME in realm $REALM..."
docker exec $(docker compose ps -q keycloak) /opt/keycloak/bin/kcadm.sh create users \
  -r "$REALM" \
  -s username="$USERNAME" \
  -s enabled=true

echo "➕ Setting password for user $USERNAME in realm $REALM..."
docker exec $(docker compose ps -q keycloak) /opt/keycloak/bin/kcadm.sh set-password \
  -r "$REALM" \
  --username "$USERNAME" \
  --new-password "$PASSWORD"

echo "✅ User $USERNAME has been created in realm $REALM."

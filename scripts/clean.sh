#!/bin/bash
set -e

VOLUME_NAME="${VOLUME_NAME:-}"
COMPOSE="${COMPOSE:-docker compose}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

echo "⚠️  This operation will remove Docker volumes and may delete persisted data."
if [ -n "$VOLUME_NAME" ]; then
  echo "   Target volume: $VOLUME_NAME"
else
  echo "   Target: all volumes defined in compose file '$COMPOSE_FILE' for this project."
fi

read -r -p "Are you sure you want to continue? [y/N]: " CONFIRM
case "$CONFIRM" in
  y|Y|yes|YES)
    echo "Proceeding with cleanup..."
    ;;
  *)
    echo "Cleanup canceled."
    exit 0
    ;;
esac

if [ -n "$VOLUME_NAME" ]; then
  if docker volume ls -q --filter "name=${VOLUME_NAME}" | grep -q "^${VOLUME_NAME}\$"; then
    docker volume rm "${VOLUME_NAME}"
    echo "Removed volume: ${VOLUME_NAME}"
  else
    echo "Volume ${VOLUME_NAME} not found"
  fi
else
  if $COMPOSE -f "$COMPOSE_FILE" config --volumes | grep -q .; then
    $COMPOSE -f "$COMPOSE_FILE" down -v
    echo "Removed volumes for current project"
  else
    echo "No volumes to remove for current project"
  fi
fi



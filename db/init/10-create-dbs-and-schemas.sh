#!/usr/bin/env bash
set -euo pipefail

# This script runs once when PGDATA is empty (first boot).
# It uses the superuser defined by POSTGRES_USER/POSTGRES_PASSWORD.

# Optional: normalize the schema name to something safe(ish)
# (schema names with dots/slashes are painful; this turns them into underscores)
SCHEMA_RAW="${BASE_API_URL:-public}"
SCHEMA_SAFE="$(printf '%s' "$SCHEMA_RAW" | tr -c '[:alnum:]_' '_' )"

DBS=(core_realm00000 workflow_realm00000)

for DB in "${DBS[@]}"; do
  echo "Ensuring database '$DB' exists…"
  if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
        -tc "SELECT 1 FROM pg_database WHERE datname = '$DB'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
        -c "CREATE DATABASE \"$DB\""
  fi

  echo "Ensuring schema '$SCHEMA_SAFE' exists in '$DB'…"
  if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" \
        -tc "SELECT 1 FROM information_schema.schemata WHERE schema_name = '$SCHEMA_SAFE'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" \
        -c "CREATE SCHEMA \"$SCHEMA_SAFE\""
  fi
done

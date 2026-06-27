#!/bin/bash
set -e

# Script to restore backup from tmp/backup.zip
# Usage: ./script/restore-backup.sh [BACKUP_FILE]
# If BACKUP_FILE is not provided, it will use the latest backup from dumps/

# Get backup file from command line argument or use default
BACKUP_FILE="${1:-tmp/backup.zip}"
EXTRACT_DIR="tmp/backup_extracted"
MANIFEST_FILE="${EXTRACT_DIR}/manifest.json"

# Function to find the latest backup directory
find_latest_backup() {
    local dumps_dir="dumps"
    if [ ! -d "$dumps_dir" ]; then
        echo "✗ Error: Dumps directory '$dumps_dir' not found!"
        exit 1
    fi
    
    # Find the most recent directory (by name, which should be timestamp-based)
    local latest_dir=$(ls -1t "$dumps_dir" | head -n1)
    if [ -z "$latest_dir" ]; then
        echo "✗ Error: No backup directories found in '$dumps_dir'!"
        exit 1
    fi
    
    echo "$dumps_dir/$latest_dir"
}

# Function to copy backup file from dumps directory
copy_backup_from_dumps() {
    local dumps_backup_dir="$1"
    local backup_zip="$dumps_backup_dir/dump.zip"
    
    if [ -f "$backup_zip" ]; then
        echo "📦 Found backup zip file: $backup_zip"
        cp "$backup_zip" "$BACKUP_FILE"
        echo "✅ Copied backup file to: $BACKUP_FILE"
    else
        echo "✗ Error: No dump.zip found in latest backup directory: $dumps_backup_dir"
        echo "Available files:"
        ls -la "$dumps_backup_dir"
        exit 1
    fi
}

# Check if backup file exists, if not try to get it from latest dumps
if [ ! -f "$BACKUP_FILE" ]; then
    echo "📁 Backup file '$BACKUP_FILE' not found, looking for latest backup in dumps..."
    latest_backup_dir=$(find_latest_backup)
    echo "📂 Found latest backup directory: $latest_backup_dir"
    copy_backup_from_dumps "$latest_backup_dir"
fi

echo "📦 Found backup file: $BACKUP_FILE"

# Create extraction directory
if [ -d "$EXTRACT_DIR" ]; then
    echo "🗑️ Removing existing extraction directory: $EXTRACT_DIR"
    rm -rf "$EXTRACT_DIR"
fi

mkdir -p "$EXTRACT_DIR"

# Extract backup file
echo "📤 Extracting backup file..."
if ! unzip -q "$BACKUP_FILE" -d "$EXTRACT_DIR"; then
    echo "✗ Failed to extract backup file!"
    exit 1
fi

echo "✅ Backup extracted successfully to: $EXTRACT_DIR"

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "✗ Error: Manifest file not found in backup: $MANIFEST_FILE"
    exit 1
fi

echo "📋 Found manifest file: $MANIFEST_FILE"

# Load current environment variables
set -o allexport
if [ -f ".env" ]; then
    source .env
else
    echo "✗ Error: .env file not found!"
    exit 1
fi
set +o allexport

# Determine the realm/space codes the backup was taken under (from the manifest)
# and the codes this installation uses (from .env). When they differ - e.g. when
# restoring a space exported from another Finmars instance into this one - the
# codes are embedded throughout the dump (schema name, user_code, configuration
# codes, ...), so they must be rewritten before import or the data will not be
# addressable under this installation's realm/space.
SRC_SPACE_CODE=$(jq -r '.space_code // empty' "$MANIFEST_FILE")
SRC_REALM_CODE=$(jq -r '.realm_code // empty' "$MANIFEST_FILE")
DST_SPACE_CODE="${BASE_API_URL}"
DST_REALM_CODE="${REALM_CODE}"

# Rewrite source realm/space codes to this installation's codes inside a SQL dump.
# No-op when the codes already match (normal same-instance restore).
# Uses a temp file + mv instead of `sed -i` for portability (GNU vs BSD sed).
rewrite_codes_in_sql() {
    local sql_file="$1"
    local sed_expr=""

    if [ -n "$SRC_SPACE_CODE" ] && [ "$SRC_SPACE_CODE" != "$DST_SPACE_CODE" ]; then
        echo "🔧 Rewriting space code '${SRC_SPACE_CODE}' -> '${DST_SPACE_CODE}' in $(basename "$sql_file")"
        sed_expr="${sed_expr}s/${SRC_SPACE_CODE}/${DST_SPACE_CODE}/g;"
    fi
    if [ -n "$SRC_REALM_CODE" ] && [ "$SRC_REALM_CODE" != "$DST_REALM_CODE" ]; then
        echo "🔧 Rewriting realm code '${SRC_REALM_CODE}' -> '${DST_REALM_CODE}' in $(basename "$sql_file")"
        sed_expr="${sed_expr}s/${SRC_REALM_CODE}/${DST_REALM_CODE}/g;"
    fi

    if [ -n "$sed_expr" ]; then
        sed "$sed_expr" "$sql_file" > "${sql_file}.tmp" && mv "${sql_file}.tmp" "$sql_file"
    fi
}

# Function to get current version for an app
get_current_version() {
    local app_name="$1"
    case "$app_name" in
        "backend")
            echo "$CORE_IMAGE_VERSION"
            ;;
        "workflow")
            echo "$WORKFLOW_IMAGE_VERSION"
            ;;
        "portal")
            echo "$PORTAL_IMAGE_VERSION"
            ;;
        "vue-portal")
            echo "$VUE_PORTAL_IMAGE_VERSION"
            ;;
        "workflow-portal")
            echo "$WORKFLOW_PORTAL_IMAGE_VERSION"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check if jq is available for JSON parsing
if ! command -v jq >/dev/null 2>&1; then
    echo "✗ Error: jq is required for JSON parsing. Please install jq."
    exit 1
fi

# Parse manifest and check versions
echo "🔍 Checking version compatibility..."

# Extract versions from manifest
backup_versions=$(jq -r '.versions[] | "\(.app)=\(.version)"' "$MANIFEST_FILE")

version_mismatch=false

# Function to compare versions by major.minor.patch
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Extract major, minor, patch from version1
    local major1=$(echo "$version1" | cut -d. -f1)
    local minor1=$(echo "$version1" | cut -d. -f2)
    local patch1=$(echo "$version1" | cut -d. -f3)
    
    # Extract major, minor, patch from version2
    local major2=$(echo "$version2" | cut -d. -f1)
    local minor2=$(echo "$version2" | cut -d. -f2)
    local patch2=$(echo "$version2" | cut -d. -f3)
    
    # Compare major version
    if [ "$major1" -gt "$major2" ]; then
        return 1  # version1 > version2
    elif [ "$major1" -lt "$major2" ]; then
        return 0  # version1 < version2
    fi
    
    # Compare minor version
    if [ "$minor1" -gt "$minor2" ]; then
        return 1  # version1 > version2
    elif [ "$minor1" -lt "$minor2" ]; then
        return 0  # version1 < version2
    fi
    
    # Compare patch version
    if [ "$patch1" -gt "$patch2" ]; then
        return 1  # version1 > version2
    elif [ "$patch1" -lt "$patch2" ]; then
        return 0  # version1 < version2
    fi
    
    return 0  # version1 == version2
}

# Check each version in the backup
while IFS='=' read -r app version; do
    current_version=$(get_current_version "$app")
    
    if [ -z "$current_version" ]; then
        echo "⚠️ Unknown app in backup: $app"
        continue
    fi
    
    if [ "$version" = "$current_version" ]; then
        echo "✅ Version match for $app: $version"
    elif version_compare "$version" "$current_version"; then
        echo "✅ Version compatible for $app: backup=$version <= current=$current_version"
    else
        echo "✗ Version incompatible for $app: backup=$version > current=$current_version"
        echo "✗ Cannot restore from a newer backup version!"
        exit 1
    fi
done <<< "$backup_versions"

# Import SQL databases from backup
echo "📥 Importing SQL databases from backup..."

# Start database container
echo "🚀 Starting PostgreSQL container..."
docker compose up -d db

sleep 5

echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec $(docker compose ps -q db) pg_isready -U ${DB_USER} > /dev/null 2>&1; do
  sleep 1
done

echo "✅ PostgreSQL is ready."

# Function to drop existing databases
drop_existing_databases() {
    echo "🗑️ Dropping existing databases before restore..."
    
    for SERVICE_NAME in backend workflow; do
        DB_NAME="${SERVICE_NAME}_realm00000"
        
        echo "🗑️ Dropping database '$DB_NAME'..."
        if docker exec $(docker compose ps -q db) psql -U ${DB_USER} -c "DROP DATABASE IF EXISTS ${DB_NAME};" > /dev/null 2>&1; then
            echo "✅ Dropped database '$DB_NAME'"
        else
            echo "⚠️ Database '$DB_NAME' may not have existed or couldn't be dropped"
        fi
    done
    
    echo "✅ Database cleanup completed"
}

# Drop existing databases
drop_existing_databases

# Import SQL files from backup
for SERVICE_NAME in backend workflow; do
  DB_NAME="${SERVICE_NAME}_realm00000"
  SQL_FILE="${SERVICE_NAME}.sql"
  
  # Check if SQL file exists in backup
  if [ ! -f "${EXTRACT_DIR}/${SQL_FILE}" ]; then
    echo "✗ Error: ${SQL_FILE} not found in backup!"
    exit 1
  fi

  # Rewrite realm/space codes when the backup was taken under different codes
  rewrite_codes_in_sql "${EXTRACT_DIR}/${SQL_FILE}"

  # Create database before importing
  echo "📦 Creating database '$DB_NAME'..."
  if ! docker exec $(docker compose ps -q db) psql -U ${DB_USER} -c "CREATE DATABASE ${DB_NAME};" > /dev/null 2>&1; then
    echo "⚠️ Database '$DB_NAME' may already exist or creation failed"
  else
    echo "✅ Created database '$DB_NAME'"
  fi
  
  echo "📥 Importing database '$DB_NAME' from '$SQL_FILE'..."
  if ! docker exec -i $(docker compose ps -q db) psql -U ${DB_USER} -d ${DB_NAME} < "${EXTRACT_DIR}/${SQL_FILE}"; then
    echo "✗ Failed to import ${SERVICE_NAME} database!"
    exit 1
  fi
  echo "✅ Imported '$DB_NAME' from '$SQL_FILE'."
done

echo "✅ SQL import completed successfully!"

# Apply migrations so a backup created on an older version is upgraded to the
# version this installation runs. This mirrors what happens on a normal
# `make up` (the *-migration services run automatically), but is done here so a
# standalone restore leaves the data ready to use. migrate_all_schemes is
# idempotent, so a same-version restore is a no-op ("No migrations to apply").
echo "🚀 Applying migrations to restored databases..."
for MIGRATION_SERVICE in core-migration workflow-migration; do
  echo "🚀 Running ${MIGRATION_SERVICE}..."
  if ! docker compose run --rm -T "${MIGRATION_SERVICE}"; then
    echo "✗ Migration '${MIGRATION_SERVICE}' failed!"
    exit 1
  fi
done
echo "✅ Migrations applied."

# If the application stack is running, restart the services that hold the data
# so they pick up the freshly restored/migrated schema. If it is not running
# (e.g. restore during initial setup), this is skipped and the services will
# start with the correct data on the next `make up`.
if [ -n "$(docker compose ps -q core)" ]; then
  echo "🔄 Restarting application services..."
  docker compose restart core core-worker workflow workflow-worker workflow-scheduler
fi

echo "🗑️ Cleaning up temporary files..."
rm -rf "$EXTRACT_DIR"

echo "🗑️ Deleting backup file..."
rm -f "$BACKUP_FILE"

echo "✅ Restore backup process completed successfully!"
echo "📁 Databases have been restored from backup!"

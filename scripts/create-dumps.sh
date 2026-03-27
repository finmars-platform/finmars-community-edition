#!/bin/bash
set -e

# Script to create a backup dump (replaces Python create_backup function)
# Usage: ./scripts/create-dumps.sh

# Load environment variables
set -o allexport
if [ -f ".env" ]; then
    source .env
else
    echo "✗ Error: .env file not found!"
    exit 1
fi
set +o allexport

# Get current timestamp in UTC
timestamp=$(date -u +%Y%m%d%H%M%S)

echo "🔄 Creating backup dump with timestamp: $timestamp"

# Start database container
echo "🚀 Starting PostgreSQL container..."
docker compose up -d db

sleep 5

echo "⏳ Waiting for PostgreSQL to be ready..."
until docker compose exec db pg_isready -U ${DB_USER} > /dev/null 2>&1; do
  sleep 1
done

# Create dump directory
DUMP_DIR="dumps/${timestamp}"
mkdir -p "$DUMP_DIR" || true

echo "📤 Exporting SQL databases..."
# Export backend database
backend_dump_filepath="${DUMP_DIR}/backend.sql"
echo "📤 Exporting database 'backend_realm00000' to 'backend.sql'..."
docker compose exec db pg_dump -U ${DB_USER} -d backend_realm00000 > "$backend_dump_filepath"
echo "✅ Exported 'backend_realm00000' to 'backend.sql'."

# Export workflow database
workflow_dump_filepath="${DUMP_DIR}/workflow.sql"
echo "📤 Exporting database 'workflow_realm00000' to 'workflow.sql'..."
docker compose exec db pg_dump -U ${DB_USER} -d workflow_realm00000 > "$workflow_dump_filepath"
echo "✅ Exported 'workflow_realm00000' to 'workflow.sql'."

# Export storage
storage_dump_filepath="${DUMP_DIR}/storage.tar.gz"
echo "📤 Exporting file storage to 'storage.tar.gz'..."
docker compose exec core tar -C /var/app/finmars_data -cz /var/app/finmars_data > "$storage_dump_filepath"
echo "✅ Exported file storage to 'storage.tar.gz'."


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

# Create manifest.json
echo "📋 Creating manifest file..."
manifest_filepath="${DUMP_DIR}/manifest.json"

# Prepare versions array
versions_json="["
first=true
for app in backend workflow portal vue-portal workflow-portal; do
    version=$(get_current_version "$app")
    if [ -n "$version" ]; then
        if [ "$first" = true ]; then
            first=false
        else
            versions_json="${versions_json},"
        fi
        versions_json="${versions_json}{\"app\":\"$app\",\"version\":\"$version\"}"
    fi
done
versions_json="${versions_json}]"

# Format date from timestamp
backup_date=$(date -d "${timestamp:0:8} ${timestamp:8:2}:${timestamp:10:2}:${timestamp:12:2}" "+%Y-%m-%d" 2>/dev/null || echo "${timestamp:0:8}")

# Create manifest.json
cat > "$manifest_filepath" << EOF
{
    "name": "Community edition",
    "space_code": "${BASE_API_URL}",
    "realm_code": "${REALM_CODE}",
    "versions": ${versions_json},
    "date": "${backup_date}",
    "owner": {
        "username": "${ADMIN_USERNAME}"
    }
}
EOF

echo "✅ Manifest file created: $manifest_filepath"

# Create zip archive
zip_filepath="${DUMP_DIR}/dump.zip"
echo "📦 Creating zip archive: $zip_filepath"

zip -j "$zip_filepath" "$manifest_filepath" "$backend_dump_filepath" "$workflow_dump_filepath" > /dev/null

echo "✅ Zip archive created: $zip_filepath"
echo "✅ Backup dump created successfully in: $DUMP_DIR"

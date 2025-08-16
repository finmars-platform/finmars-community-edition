#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
API_URL="https://license.finmars.com/api/v1/version/get-latest/?channel=stable"

# Require jq early (both mac & linux)
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. Install it (e.g., on macOS: brew install jq)." >&2
  exit 1
fi

TMP_FILE=$(mktemp)

# Map env var -> app name (portable: no associative arrays)
map_var_to_app() {
  case "$1" in
    CORE_IMAGE_VERSION)               echo "backend" ;;
    WORKFLOW_IMAGE_VERSION)           echo "workflow" ;;
    # START_PAGE_IMAGE_VERSION)       echo "start-page" ;;   # left commented like your original
    PORTAL_IMAGE_VERSION)             echo "portal" ;;
    VUE_PORTAL_IMAGE_VERSION)         echo "vue-portal" ;;
    WORKFLOW_PORTAL_IMAGE_VERSION)    echo "workflow-portal" ;;
    *)                                echo "" ;;
  esac
}

# Ensure keys exist in .env
ensure_key() {
  local key="$1"
  if ! grep -q "^${key}=" "$ENV_FILE"; then
    echo "${key}=" >> "$ENV_FILE"
    echo "Added missing key: ${key}"
  fi
}

ensure_key "CORE_IMAGE_VERSION"
ensure_key "WORKFLOW_IMAGE_VERSION"
# ensure_key "START_PAGE_IMAGE_VERSION"  # as per your original, commented
ensure_key "PORTAL_IMAGE_VERSION"
ensure_key "VUE_PORTAL_IMAGE_VERSION"
ensure_key "WORKFLOW_PORTAL_IMAGE_VERSION"

echo "Fetching latest versions from API..."
if ! curl -s --location "$API_URL" -o "$TMP_FILE"; then
  echo "Error: Failed to fetch versions from API" >&2
  rm -f "$TMP_FILE"
  exit 1
fi

cp "$ENV_FILE" "${ENV_FILE}.bak"
echo "Created backup of .env file at ${ENV_FILE}.bak"

# Build a safe lookup function using jq (once) to avoid repeated scans
get_latest_version() {
  local app="$1"
  jq -r --arg app "$app" '.results[] | select(.app == $app) | .version' "$TMP_FILE" | tail -n1
}

# Rewrite .env safely
# Note: We don't source .env; we process it line-by-line to avoid shell interpretation.
{
  while IFS= read -r line || [ -n "$line" ]; do
    # Preserve blank lines
    if [ -z "$line" ]; then
      echo ""
      continue
    fi

    # Preserve full-line comments (leading whitespace allowed)
    case "$line" in
      ([" "][$'\t']*"#"*) echo "$line"; continue ;;
      ("#"*)              echo "$line"; continue ;;
    esac

    # Parse KEY=VALUE (keep everything after first = as value)
    if printf '%s\n' "$line" | grep -q '^[^=]\+='; then
      key=${line%%=*}
      value=${line#*=}

      # Strip inline comments from value (anything after ' #'), but preserve quoted values
      # If value starts with a quote, leave it as-is
      case "$value" in
        (\"*|\'*) : ;;   # assumed intentional quoted value; do not strip trailing comments
        (*) value=$(printf '%s\n' "$value" | sed 's/[[:space:]]*#.*$//') ;;
      esac
      # Trim trailing whitespace
      # shellcheck disable=SC2001
      value=$(printf '%s' "$value" | sed 's/[[:space:]]*$//')

      app_name="$(map_var_to_app "$key")"
      if [ -n "$app_name" ]; then
        latest_version="$(get_latest_version "$app_name")"
        if [ -n "$latest_version" ] && [ "$value" != "$latest_version" ]; then
          echo "${key}=${latest_version}"
        else
          echo "$line"
        fi
      else
        echo "$line"
      fi
    else
      # Unrecognized line (no '='): keep as-is
      echo "$line"
    fi
  done < "$ENV_FILE"
} > "${ENV_FILE}.new"

mv "${ENV_FILE}.new" "$ENV_FILE"
rm -f "$TMP_FILE"

echo "Version update complete!"

#!/bin/bash

ENV_FILE=".env"

API_URL="https://license.finmars.com/api/v1/version/get-latest/?channel=stable"

TMP_FILE=$(mktemp)

echo "Fetching latest versions from API..."
curl -s --location "$API_URL" -o "$TMP_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch versions from API"
    rm "$TMP_FILE"
    exit 1
fi

declare -A APP_MAPPING=(
    ["CORE_IMAGE_VERSION"]="backend"
    ["WORKFLOW_IMAGE_VERSION"]="workflow"
    # ["START_PAGE_IMAGE_VERSION"]="start-page"
    ["PORTAL_IMAGE_VERSION"]="portal"
    ["VUE_PORTAL_IMAGE_VERSION"]="vue-portal"
    ["WORKFLOW_PORTAL_IMAGE_VERSION"]="workflow-portal"
)

cp "$ENV_FILE" "${ENV_FILE}.bak"
echo "Created backup of .env file at ${ENV_FILE}.bak"

while IFS= read -r line || [ -n "$line" ]; do
    if [[ -z "$line" ]]; then
        echo ""
        continue
    fi
    
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
        echo "$line"
        continue
    fi
    
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        var="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        
        value=$(echo "$value" | sed 's/[[:space:]]*#.*$//')
        value="${value%"${value##*[![:space:]]}"}"
        
        if [[ -n "${APP_MAPPING[$var]}" ]]; then
            app_name="${APP_MAPPING[$var]}"
            
            latest_version=$(jq -r ".results[] | select(.app == \"$app_name\") | .version" "$TMP_FILE")
            
            if [ -z "$latest_version" ]; then
                echo "$line"
                continue
            fi
            
            if [ "$value" != "$latest_version" ]; then
                echo "$var=$latest_version"
            else
                echo "$line"
            fi
        else
            echo "$line"
        fi
    else
        echo "$line"
    fi
done < "$ENV_FILE" > "${ENV_FILE}.new"

mv "${ENV_FILE}.new" "$ENV_FILE"

rm "$TMP_FILE"

echo "Version update complete!"

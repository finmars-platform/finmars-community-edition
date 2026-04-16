#!/usr/bin/env sh
# Usage: install-demo.sh <database-dump>

# Note: will not work when sourced from a different directory
script_dir=$(dirname "$0")
. "$script_dir/common_functions.sh"


dump_name="$1"
dump_file="db-dump-$dump_name"

print_step "Downloading database configuration"
s3_url="https://finmars-public.s3.eu-central-1.amazonaws.com"
curl -o "$dump_file.zip" "$s3_url/$dump_file.zip"

print_step "Setting up environment"
generate-env.sh -k -u "$ADMIN_USERNAME" -p "$ADMIN_PASSWORD" l

print_step "Downloading Finmars"
if [ -n "$installer_mode" ]; then
    export COMPOSE_PROGRESS=json
fi
docker compose pull

if [ ! -d "nginx/ssl/live" ]; then
  #print_step "Setting up certificates"
  init-cert.sh
fi

print_step "Adding users"
init-keycloak.sh

print_step "Checking for updates"
update-versions.sh

print_step "Importing configuration"
restore-backup.sh "$dump_file.zip"

print_step "Adjusting database configuration"
patch-demo-database.sh

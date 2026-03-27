#!/usr/bin/env sh
# Usage: install-demo.sh <database-dump>

dump_name="$1"
dump_file="db-dump-$dump_name"

s3_url="https://finmars-public.s3.eu-central-1.amazonaws.com"
curl -o "$dump_file.zip" "$s3_url/$dump_file.zip"

generate-env.sh -k -u "$ADMIN_USERNAME" -p "$ADMIN_PASSWORD" l
if [ ! -d "nginx/ssl/live" ]; then
  init-cert.sh
fi
init-keycloak.sh
update-versions.sh
restore-backup.sh "$dump_file.zip"
patch-demo-database.sh
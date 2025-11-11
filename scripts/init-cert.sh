#!/bin/bash
set -e

set -o allexport
source .env
set +o allexport


if [[ "$ENVIRONMENT_TYPE" == "production" ]]; then
   docker compose up certbot
   sudo chown -R "$USER:$(id -gn)" nginx/ssl
else
   mkdir -p nginx/ssl/live/$MAIN_DOMAIN_NAME

   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout ./nginx/ssl/live/$MAIN_DOMAIN_NAME/privkey.pem \
   -out ./nginx/ssl/live/$MAIN_DOMAIN_NAME/fullchain.pem \
   -config ./openssl.conf
fi

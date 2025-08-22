#!/bin/bash

if [ -f .env ]; then
  read -p ".env already exists. Overwrite? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted. Keeping existing .env file."
    exit 0
  fi
fi

PROTO="https"
COMPOSE_FILE="docker-compose.yml"

read -p "Which version will you use? Development or production (d/P): " confirm
if [[ ! "$confirm" =~ ^[Dd]$ ]]; then
  ENVIRONMENT_TYPE=production
  AUTH_DOMAIN_PORT=443

  read -p "Enter MAIN_DOMAIN_NAME (e.g., ap-finmars.finmars.com): " MAIN_DOMAIN_NAME
  MAIN_DOMAIN_NAME=${MAIN_DOMAIN_NAME}
  read -p "Enter AUTH_DOMAIN_NAME (e.g., ap-finmars-auth.finmars.com): " AUTH_DOMAIN_NAME
  AUTH_DOMAIN_NAME=${AUTH_DOMAIN_NAME}
  INTERNAL_AUTH_DOMAIN=${AUTH_DOMAIN_NAME}
  INTERNAL_MAIN_DOMAIN=${MAIN_DOMAIN_NAME}
  VERIFY_SSL=True
else
  ENVIRONMENT_TYPE=development
  AUTH_DOMAIN_PORT=8004
  MAIN_DOMAIN_NAME=127.0.0.1
  AUTH_DOMAIN_NAME=127.0.0.1:8004
  INTERNAL_AUTH_DOMAIN=nginx:8004
  INTERNAL_MAIN_DOMAIN=nginx
  VERIFY_SSL=False
fi


read -p "Enter ADMIN_USERNAME: " ADMIN_USERNAME
read -sp "Enter ADMIN_PASSWORD: " ADMIN_PASSWORD
echo

ESCAPED_ADMIN_USERNAME=$(printf '%s\n' "$ADMIN_USERNAME" | sed -e 's/[\/&]/\\&/g')
ESCAPED_ADMIN_PASSWORD=$(printf '%s\n' "$ADMIN_PASSWORD" | sed -e 's/[\/&]/\\&/g')

SECRET_KEY=$(openssl rand -hex 4)
JWT_SECRET_KEY=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)
KC_DB_PASSWORD=$(openssl rand -hex 16)

sed \
  -e "s|^SECRET_KEY=.*|SECRET_KEY=${SECRET_KEY}|" \
  -e "s|^JWT_SECRET_KEY=.*|JWT_SECRET_KEY=${JWT_SECRET_KEY}|" \
  -e "s|^ENCRYPTION_KEY=.*|ENCRYPTION_KEY=${ENCRYPTION_KEY}|" \
  -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" \
  -e "s|^KC_DB_PASSWORD=.*|KC_DB_PASSWORD=${KC_DB_PASSWORD}|" \
  -e "s|^DOMAIN_NAME=.*|DOMAIN_NAME=${INTERNAL_MAIN_DOMAIN}|" \
  -e "s|^CSRF_COOKIE_DOMAIN=.*|CSRF_COOKIE_DOMAIN=${MAIN_DOMAIN_NAME}|" \
  -e "s|^CSRF_TRUSTED_ORIGINS=.*|CSRF_TRUSTED_ORIGINS=${PROTO}://${MAIN_DOMAIN_NAME}|" \
  -e "s|^PROD_APP_HOST=.*|PROD_APP_HOST=${PROTO}://${MAIN_DOMAIN_NAME}|" \
  -e "s|^APP_HOST=.*|APP_HOST=${PROTO}://${MAIN_DOMAIN_NAME}|" \
  -e "s|^PROD_API_HOST=.*|PROD_API_HOST=${PROTO}://${MAIN_DOMAIN_NAME}|" \
  -e "s|^API_HOST=.*|API_HOST=${PROTO}://${MAIN_DOMAIN_NAME}|" \
  -e "s|^KEYCLOAK_SERVER_URL=.*|KEYCLOAK_SERVER_URL=${PROTO}://${INTERNAL_AUTH_DOMAIN}|" \
  -e "s|^KEYCLOAK_URL=.*|KEYCLOAK_URL=${PROTO}://${AUTH_DOMAIN_NAME}|" \
  -e "s|^PROD_KEYCLOAK_URL=.*|PROD_KEYCLOAK_URL=${PROTO}://${AUTH_DOMAIN_NAME}|" \
  -e "s|^ADMIN_USERNAME=.*|ADMIN_USERNAME=${ESCAPED_ADMIN_USERNAME}|" \
  -e "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=${ESCAPED_ADMIN_PASSWORD}|" \
  -e "s|^MAIN_DOMAIN_NAME=.*|MAIN_DOMAIN_NAME=${MAIN_DOMAIN_NAME}|" \
  -e "s|^AUTH_DOMAIN_NAME=.*|AUTH_DOMAIN_NAME=${AUTH_DOMAIN_NAME}|" \
  -e "s|^REDIRECT_PATH=.*|REDIRECT_PATH=\"/realm00000/space00000/a/#!/dashboard\"|" \
  -e "s|^ENVIRONMENT_TYPE=.*|ENVIRONMENT_TYPE=${ENVIRONMENT_TYPE}|" \
  -e "s|^AUTH_DOMAIN_PORT=.*|AUTH_DOMAIN_PORT=${AUTH_DOMAIN_PORT}|" \
  -e "s|^VERIFY_SSL=.*|VERIFY_SSL=${VERIFY_SSL}|" \
  .env.sample > .env

echo ".env file created successfully from .env.sample."

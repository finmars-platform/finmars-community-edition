#!/bin/bash

show_help() {
  cat - <<EOF
$0 [OPTIONS…] [ENVIRONMENT_TYPE]

OPTIONS:
  -k|--keep-env  Never overwrite the .env file
  -u|--username  The admin username
  -p|--password  The admin password
  -h|--help      Show this help

ARGUMENTS:
  ENVIRONMENT_TYPE=l|h  The environment type to setup, (l)ocal or (p)roduction

EOF
}

overwrite_env=
ADMIN_USERNAME=
ADMIN_PASSWORD=

# Handle CLI options
while :; do
  case "$1" in
    -h|--help)
      show_help
      exit
      ;;
    -k|--keep-env)
      overwrite_env=n
      ;;
    -u|--username)
      if [ -n "$2" ]; then
        ADMIN_USERNAME="$2"
        shift
      else
        echo "Error: must specify username after --username" >&2
        exit 255
      fi
      ;;
    -p|--password)
      if [ -n "$2" ]; then
        ADMIN_PASSWORD="$2"
        shift
      else
        echo "Error: must specify password after --password" >&2
        exit 255
      fi
      ;;
    --)
      break
      ;;
    *)
      break
      ;;
    esac
    shift
done

# Handle arguments
environment_type="$1"
shift

if [ -f .env ]; then
  if [ -z "$overwrite_env" ]; then
    read -p ".env already exists. Overwrite? (y/N): " overwrite_env
  fi
  if [[ ! "$overwrite_env" =~ ^[Yy]$ ]]; then
    echo "Aborted. Keeping existing .env file."
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
      return 0
    else
      exit 0
    fi
  fi
fi

PROTO="https"
COMPOSE_FILE="docker-compose.yml"

if [ -z "$environment_type" ]; then
  read -p "Which version will you use? Local or production (l/P): " environment_type
fi

if [[ ! "$environment_type" =~ ^[Ll]$ ]]; then
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

if [ -z "$ADMIN_USERNAME" ]; then
  read -p "Enter ADMIN_USERNAME: " ADMIN_USERNAME
fi
if [ -z "$ADMIN_PASSWORD" ]; then
  read -sp "Enter ADMIN_PASSWORD: " ADMIN_PASSWORD
fi
echo

ESCAPED_ADMIN_USERNAME=$(printf '%s\n' "$ADMIN_USERNAME" | sed -e 's/[\/&]/\\&/g')
ESCAPED_ADMIN_PASSWORD=$(printf '%s\n' "$ADMIN_PASSWORD" | sed -e 's/[\/&]/\\&/g')

SECRET_KEY=$(openssl rand -hex 4)
JWT_SECRET_KEY=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)
KC_DB_PASSWORD=$(openssl rand -hex 16)
RABBITMQ_PASSWORD=$(openssl rand -hex 16)
FLASK_SECRET_KEY=$(openssl rand -hex 32)

sed \
  -e "s|^SECRET_KEY=.*|SECRET_KEY=${SECRET_KEY}|" \
  -e "s|^JWT_SECRET_KEY=.*|JWT_SECRET_KEY=${JWT_SECRET_KEY}|" \
  -e "s|^ENCRYPTION_KEY=.*|ENCRYPTION_KEY=${ENCRYPTION_KEY}|" \
  -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" \
  -e "s|^KC_DB_PASSWORD=.*|KC_DB_PASSWORD=${KC_DB_PASSWORD}|" \
  -e "s|^RABBITMQ_PASSWORD=.*|RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}|" \
  -e "s|^FLASK_SECRET_KEY=.*|FLASK_SECRET_KEY=${FLASK_SECRET_KEY}|" \
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

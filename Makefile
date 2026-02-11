-include .env

export

COMPOSE = docker compose
COMPOSE_FILE ?= docker-compose.yml
# Use ':' for all OS's. By default, Docker uses ':' on Linux/MacOS and ';' on Windows.
COMPOSE_PATH_SEPARATOR = :

# Read ENVIRONMENT_TYPE from .env, taking quotes into account
ENVIRONMENT_TYPE=$(shell if [ -f .env ]; then grep '^ENVIRONMENT_TYPE=' .env | cut -d '=' -f 2- | sed 's/^["'\'']\(.*\)["'\'']$$/\1/'; fi)

# Adjust settings for development environments
ifeq (${ENVIRONMENT_TYPE},development)
	COMPOSE_FILE := $(COMPOSE_FILE):docker-compose.dev.yml
endif

.PHONY: generate-env init-keycloak init-cert update-versions up down db logs clean create-dumps restore-backup install no-target tests add-user list-users setup-ui env-present-%
.DEFAULT_GOAL := no-target


no-target:
	$(error No default target; please specify a goal, e.g. 'make install')

install:
	./scripts/install.sh

generate-env:
	./scripts/generate-env.sh

init-keycloak:
	./scripts/init-keycloak.sh

init-cert:
	./scripts/init-cert.sh

update-versions:
	./scripts/update-versions.sh

up: env-set-ENVIRONMENT_TYPE
	$(COMPOSE) up --build -d \
	--remove-orphans \
	--scale certbot=0
	@echo ""
	@echo "Opening https://$(MAIN_DOMAIN_NAME) in browser..."

down: env-set-ENVIRONMENT_TYPE
	$(COMPOSE) down

db: env-set-ENVIRONMENT_TYPE
	docker compose up -d db

logs: env-set-ENVIRONMENT_TYPE
	docker compose logs -f

linters:
	ruff format; \
	ruff check --fix; \

tests:
	pytest

create-dumps:
	./scripts/create-dumps.sh

restore-backup:
	./scripts/restore-backup.sh

add-user:
	./scripts/add-keycloak-user.sh --username $(USERNAME) --password $(PASSWORD)

list-users:
	./scripts/list-keycloak-users.sh

clean: env-set-ENVIRONMENT_TYPE
	VOLUME_NAME="$(VOLUME_NAME)" COMPOSE="$(COMPOSE)" COMPOSE_FILE="$(COMPOSE_FILE)" ./scripts/clean.sh

setup-ui:
	./scripts/setup-ui.sh

# Check if a enviornment variable is set
# env-set-FOO will check whether $FOO is set
env-set-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "$* not set in .env. Run make install or update your .env file"; \
		exit 1; \
	fi

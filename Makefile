-include .env

export

COMPOSE = docker compose
COMPOSE_FILE ?= docker-compose.yml
# Use ':' for all OS's. By default, Docker uses ':' on Linux/MacOS and ';' on Windows.
COMPOSE_PATH_SEPARATOR = :

ifdef DEV
	COMPOSE_FILE := $(COMPOSE_FILE):docker-compose.dev.yml
endif

.PHONY: generate-env init-keycloak init-cert update-versions up down db logs clean create-dumps restore-backup install no-target tests add-user list-users setup-ui
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

up:
	$(COMPOSE) up --build -d \
	--remove-orphans \
	--scale certbot=0
	@echo ""
	@echo "Opening https://$(MAIN_DOMAIN_NAME) in browser..."

down:
	$(COMPOSE) down

db:
	docker compose up -d db

logs:
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

clean:
	VOLUME_NAME="$(VOLUME_NAME)" COMPOSE="$(COMPOSE)" COMPOSE_FILE="$(COMPOSE_FILE)" ./scripts/clean.sh

setup-ui:
	./scripts/setup-ui.sh

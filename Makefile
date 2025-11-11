-include .env

export

COMPOSE = docker compose
COMPOSE_FILE ?= docker-compose.yml

.PHONY: generate-env init-keycloak init-cert update-versions up down db logs clean create-dumps restore-backup install no-target
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
	$(COMPOSE) -f $(COMPOSE_FILE) up --build -d \
	--remove-orphans \
	--scale certbot=0

down:
	$(COMPOSE) down

db:
	docker compose up -d db

logs:
	docker compose logs -f

linters:
	ruff format; \
	ruff check --fix; \

create-dumps:
	./scripts/create-dumps.sh

restore-backup:
	./scripts/restore-backup.sh

clean:
	@if [ -n "$(VOLUME_NAME)" ]; then \
		if [ "$$(docker volume ls -q --filter name=$(VOLUME_NAME))" ]; then \
			docker volume rm $(VOLUME_NAME); \
			echo "Removed volume: $(VOLUME_NAME)"; \
		else \
			echo "Volume $(VOLUME_NAME) not found"; \
		fi; \
	else \
		if [ "$$($(COMPOSE) -f $(COMPOSE_FILE) config --volumes)" ]; then \
			$(COMPOSE) -f $(COMPOSE_FILE) down -v; \
			echo "Removed volumes for current project"; \
		else \
			echo "No volumes to remove for current project"; \
		fi; \
	fi

-include .env

export

COMPOSE = docker compose
COMPOSE_FILE ?= docker-compose.yml

.PHONY: generate-env init-keycloak init-cert update-versions migrate up down restart-nginx import-sql export-sql db logs clean backup-storage restore-storage create-backup


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

restart-nginx:
	docker exec -i finmars-community-edition-nginx-1 nginx -s reload

import-sql: 
	./scripts/import-sql.sh

export-sql:
	./scripts/export-sql.sh

backup-storage:
	./scripts/backup-storage.sh

db:
	docker compose up -d db

logs:
	docker compose logs -f

linters:
	ruff format; \
	ruff check --fix; \

clean:
	@if [ "$$($(COMPOSE) -f $(COMPOSE_FILE) config --volumes)" ]; then \
		$(COMPOSE) -f $(COMPOSE_FILE) down -v; \
		echo "Removed volumes for current project"; \
	else \
		echo "No volumes to remove for current project"; \
	fi

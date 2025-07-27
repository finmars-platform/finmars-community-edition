-include .env

export

COMPOSE = docker compose
COMPOSE_FILE ?= docker-compose.yml

.PHONY: generate-env init-keycloak init-cert update-versions migrate up down restart-nginx import-sql export-sql db logs


generate-env:
	./generate-env.sh

init-keycloak:
	./init-keycloak.sh

init-cert:
	docker compose up certbot

update-versions:
	./update-versions.sh

migrate:
	./migrate.sh

up:
	$(COMPOSE) -f $(COMPOSE_FILE) up --build -d \
	--remove-orphans \
	--scale core-migration=0 \
	--scale workflow-migration=0 \
	--scale certbot=0

down:
	$(COMPOSE) down

restart-nginx:
	docker exec -i finmars-community-edition-nginx-1 nginx -s reload

import-sql: 
	./import-sql.sh

export-sql:
	./export-sql.sh

db:
	docker compose up -d db

logs:
	docker compose logs -f

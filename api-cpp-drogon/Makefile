COMPOSE    := docker compose -f ../docker-compose.yml
BUILD_DIR  := build
BUILD_TYPE ?= Release
BASE_URL   ?= http://nginx

# Local run defaults: talk to the Postgres container published on localhost.
export DB_HOST     ?= localhost
export DB_PORT     ?= 5432
export DB_NAME     ?= apibattle
export DB_USER     ?= apibattle
export DB_PASSWORD ?= apibattle
export PORT        ?= 8080

.DEFAULT_GOAL := help

.PHONY: help up down restart logs ps db build run load-test clean reset

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

## --- Docker (full stack: Postgres + API replicas + Nginx on :9999) ---

up: ## Build and start the full stack
	$(COMPOSE) up -d --build --wait

down: ## Stop the stack
	$(COMPOSE) down

restart: down up ## Restart the stack

logs: ## Follow API logs
	$(COMPOSE) logs -f api

ps: ## Show stack containers
	$(COMPOSE) ps

reset: ## Stop the stack and wipe the database volume
	$(COMPOSE) down -v

load-test: ## Run the k6 load test against the running stack
	docker run --rm -i --network apibattle_default -e BASE_URL=$(BASE_URL) \
		-v "$(CURDIR)/../k6:/scripts" grafana/k6 run /scripts/load-test.js

## --- Local (requires Drogon installed, e.g. `brew install drogon`) ---

db: ## Start only Postgres (for running the API locally)
	$(COMPOSE) up -d --wait postgres

build: ## Compile the API locally
	cmake -S . -B $(BUILD_DIR) -DCMAKE_BUILD_TYPE=$(BUILD_TYPE)
	cmake --build $(BUILD_DIR) -j

run: build db ## Compile and run the API locally on $(PORT)
	./$(BUILD_DIR)/apibattle_api

clean: ## Remove local build artifacts
	rm -rf $(BUILD_DIR)

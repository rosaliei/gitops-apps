# Shortcuts for what CI does, so you can run it on your laptop.
# Deploying is NOT done from here: it happens in the GitOps repo (github.com/rosaliei/gitops-monorepo).
APPS        := orders-api inventory-svc web-frontend
GITOPS_REPO ?= https://github.com/rosaliei/gitops-monorepo.git

.PHONY: help test build e2e

help: ## show targets
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

test: ## lint + unit tests for all apps (Python runs in Docker, so only Docker + Node are needed)
	docker run --rm -v "$(CURDIR)/orders-api:/src" -w /src python:3.12-slim \
	  sh -c "pip install -q -r requirements-dev.txt && ruff check . && pytest -q"
	cd inventory-svc && npm ci --silent && npm run lint && npm test
	cd web-frontend && npm run lint && npm test

build: ## build all images locally (local/<app>:dev)
	@for app in $(APPS); do docker build -q -t local/$$app:dev $$app && echo "built local/$$app:dev"; done

e2e: ## run these apps with the REAL chart from the GitOps repo on a throwaway kind cluster
	[ -d .gitops/.git ] && git -C .gitops pull -q || git clone -q --depth 1 $(GITOPS_REPO) .gitops
	APPS_DIR=$(CURDIR) .gitops/scripts/e2e.sh

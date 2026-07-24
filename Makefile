# Development & Build Commands
.PHONY: help install dev build preview clean lint format test push deploy aws-secret aws-secret-file aws-db-secret aws-setup aws-status

help:
	@echo "Crossplane AWS Demo - Available Commands"
	@echo "=========================================="
	@echo ""
	@echo "Development:"
	@echo "  make install      Install dependencies"
	@echo "  make dev          Start development server (Vite)"
	@echo "  make build        Build for production"
	@echo "  make preview      Preview production build locally"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint         Run TypeScript type checking"
	@echo "  make format       Format code with Prettier"
	@echo "  make format-check Check code formatting without changes"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build     Build production Docker image"
	@echo "  make docker-dev       Build development Docker image"
	@echo "  make docker-run       Run production container"
	@echo "  make docker-compose   Start stack with docker-compose"
	@echo ""
	@echo "AWS / Crossplane:"
	@echo "  make aws-secret       Create or update the AWS credentials secret"
	@echo "  make aws-secret-file  Create the AWS credentials secret from a specific file"
	@echo "  make aws-db-secret    Create or update the DB password secret"
	@echo "  make aws-setup        Apply the full Crossplane resource stack"
	@echo "  make aws-status       Show providers and managed resources"
	@echo ""
	@echo "Terraform:"
	@echo "  make tf-init      Initialize Terraform"
	@echo "  make tf-plan      Plan infrastructure changes"
	@echo "  make tf-apply     Apply infrastructure changes"
	@echo "  make tf-destroy   Destroy infrastructure"
	@echo "  make tf-validate  Validate Terraform configuration"
	@echo ""
	@echo "Git:"
	@echo "  make push         Commit and push all changes"
	@echo "  make status       Show git status"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean        Remove build artifacts"
	@echo "  make clean-all    Remove node_modules, dist, cache"
	@echo ""

# Installation
install:
	npm install

# Development
dev:
	npm run dev

build:
	npm run build

preview:
	npm run preview

# Code Quality
lint:
	npm run lint

format:
	npx prettier --write src/ tsconfig.json vite.config.ts

format-check:
	npx prettier --check src/ tsconfig.json vite.config.ts

# Kubernetes / Crossplane
aws-secret:
	@if [ -f "$$HOME/.aws/credentials" ]; then \
		kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=$$HOME/.aws/credentials --dry-run=client -o yaml | kubectl apply -f -; \
	else \
		echo "No AWS credentials file found at $$HOME/.aws/credentials"; \
		exit 1; \
	fi

aws-secret-file FILE=./creds.conf:
	kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=$(FILE) --dry-run=client -o yaml | kubectl apply -f -

aws-db-secret PASSWORD=SuperSecret123!:
	kubectl create secret generic db-password --from-literal=password=$(PASSWORD) --dry-run=client -o yaml | kubectl apply -f -

aws-setup:
	kubectl apply -f crossplane-manifests/1-providers.yaml
	kubectl apply -f crossplane-manifests/2-providerconfig.yaml
	kubectl apply -f crossplane-manifests/3-s3-bucket.yaml
	kubectl apply -f crossplane-manifests/4-rds-instance.yaml
	kubectl apply -f crossplane-manifests/5-iam-role.yaml
	kubectl apply -f crossplane-manifests/6-dynamodb-table.yaml

aws-status:
	kubectl get providers
	kubectl get managed

# Docker
docker-build:
	docker build -t crossplane-demo:latest .

docker-dev:
	docker build -f Dockerfile.dev -t crossplane-demo:dev .

docker-run: docker-build
	docker run -p 3000:3000 \
		-e GEMINI_API_KEY=${GEMINI_API_KEY} \
		crossplane-demo:latest

docker-compose:
	docker-compose up

docker-compose-dev:
	docker-compose --profile dev up

# Terraform
tf-init:
	cd terraform && terraform init -backend=false

tf-plan:
	cd terraform && terraform plan

tf-apply:
	cd terraform && terraform apply

tf-destroy:
	cd terraform && terraform destroy

tf-validate:
	cd terraform && terraform validate && tflint

# Git
push: clean
	git add -A && git commit -m "chore: update project" && git push origin main

status:
	git status

# Cleanup
clean:
	npm run clean
	rm -rf coverage
	rm -f *.log

clean-all: clean
	rm -rf node_modules dist
	rm -rf .next .turbo .cache

# Install dev dependencies for ESLint and Prettier
setup-lint:
	npm install --save-dev eslint prettier @typescript-eslint/eslint-plugin @typescript-eslint/parser eslint-plugin-react eslint-plugin-react-hooks eslint-config-prettier

# Documentation
docs:
	@echo "See docs/ directory for:"
	@echo "  - DEPLOYMENT.md      Deployment guides"
	@echo "  - DEVELOPMENT.md     Development guide"
	@echo "  - CONTRIBUTING.md    Contributing guidelines"
	@echo "  - IMPROVEMENTS_SUMMARY.md  All improvements made"

.DEFAULT_GOAL := help

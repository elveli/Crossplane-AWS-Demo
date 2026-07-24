# Development & Build Commands
.PHONY: help npm-install dev npm-build preview test deploy aws-secret aws-secret-file aws-db-secret aws-setup teardown aws-status crossplane-install crossplane-status logs-crossplane logs-s3 logs-rds logs-iam logs-dynamodb inventory kubeconfig pods nodes nodegroups crossplane-resources crossplane-watch

AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUCKET ?= crossplane-demo-tfstate$(if $(AWS_ACCOUNT_ID),-$(AWS_ACCOUNT_ID),)
REGION ?= us-east-1
TABLE ?= terraform-locks

help:
	@echo "Crossplane AWS Demo - Available Commands"
	@echo "=========================================="
	@echo ""
	@echo "Development"
	@printf "  %-18s %s\n" "make npm-install" "Install dependencies"
	@printf "  %-18s %s\n" "make dev" "Start development server (Vite)"
	@printf "  %-18s %s\n" "make npm-build" "Build for production"
	@printf "  %-18s %s\n" "make preview" "Preview production build locally"
	@echo ""
	@echo "Docker"
	@printf "  %-18s %s\n" "make docker-build" "Build production Docker image"
	@printf "  %-18s %s\n" "make docker-dev" "Build development Docker image"
	@printf "  %-18s %s\n" "make docker-run" "Run production container"
	@printf "  %-18s %s\n" "make docker-compose" "Start stack with docker-compose"
	@echo ""
	@echo "AWS / Crossplane"
	@printf "  %-18s %s\n" "make aws-secret" "Create or update the AWS credentials secret"
	@printf "  %-18s %s\n" "make aws-secret-file" "Create the AWS credentials secret from a specific file"
	@printf "  %-18s %s\n" "make aws-db-secret" "Create or update the DB password secret"
	@printf "  %-18s %s\n" "make aws-setup" "Apply the full Crossplane resource stack"
	@printf "  %-18s %s\n" "make teardown" "Delete Crossplane resources, then destroy Terraform infrastructure"
	@printf "  %-18s %s\n" "make aws-status" "Show providers and managed resources"
	@printf "  %-18s %s\n" "make crossplane-install" "Install or upgrade Crossplane via Helm"
	@printf "  %-18s %s\n" "make crossplane-status" "Show Crossplane pods and release status"
	@printf "  %-18s %s\n" "make logs-crossplane" "Tail logs from the core Crossplane pod"
	@printf "  %-18s %s\n" "make logs-s3" "Tail logs from the AWS S3 provider"
	@printf "  %-18s %s\n" "make logs-rds" "Tail logs from the AWS RDS provider"
	@printf "  %-18s %s\n" "make logs-iam" "Tail logs from the AWS IAM provider"
	@printf "  %-18s %s\n" "make logs-dynamodb" "Tail logs from the AWS DynamoDB provider"
	@printf "  %-18s %s\n" "make kubeconfig" "Update local kubeconfig for the deployed EKS cluster"
	@printf "  %-18s %s\n" "make pods" "Show all pods across namespaces"
	@printf "  %-18s %s\n" "make nodes" "Show cluster nodes with instance-type and capacity-type labels"
	@printf "  %-18s %s\n" "make nodegroups" "Show EKS managed node groups and their status"
	@printf "  %-18s %s\n" "make crossplane-resources" "Show the Crossplane-managed AWS resources"
	@printf "  %-18s %s\n" "make crossplane-watch" "Watch the Crossplane-managed AWS resources until ready"
	@printf "  %-18s %s\n" "make inventory" "Show a basic AWS inventory for the deployed resources"
	@echo ""
	@echo "Terraform"
	@printf "  %-18s %s\n" "make tf-init" "Initialize Terraform with the S3 backend"
	@printf "  %-18s %s\n" "make tf-backend-create" "Create the S3 backend bucket and DynamoDB lock table"
	@printf "  %-18s %s\n" "make tf-plan" "Plan infrastructure changes"
	@printf "  %-18s %s\n" "make tf-apply" "Apply infrastructure changes"
	@printf "  %-18s %s\n" "make tf-destroy" "Destroy infrastructure"
	@printf "  %-18s %s\n" "make tf-validate" "Validate Terraform configuration"
	@echo ""

# Installation
npm-install:
	npm install

# Development
dev:
	npm run dev

npm-build:
	npm run build

preview:
	npm run preview

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

aws-db-secret:
	kubectl create secret generic db-password --from-literal=password=$(PASSWORD) --dry-run=client -o yaml | kubectl apply -f -

aws-setup:
	kubectl apply -f crossplane-manifests/1-providers.yaml
	kubectl wait --for=condition=Healthy providers.pkg.crossplane.io --all --timeout=10m
	kubectl apply -f crossplane-manifests/2-providerconfig.yaml
	kubectl apply -f crossplane-manifests/3-s3-bucket.yaml
	kubectl apply -f crossplane-manifests/4-rds-instance.yaml
	kubectl apply -f crossplane-manifests/5-iam-role.yaml
	kubectl apply -f crossplane-manifests/6-dynamodb-table.yaml

teardown:
	kubectl delete -f crossplane-manifests/6-dynamodb-table.yaml
	kubectl delete -f crossplane-manifests/5-iam-role.yaml
	kubectl delete -f crossplane-manifests/4-rds-instance.yaml
	kubectl delete -f crossplane-manifests/3-s3-bucket.yaml
	cd terraform && terraform destroy -auto-approve

aws-status:
	kubectl get providers.pkg.crossplane.io
	kubectl get providerconfigs.aws.upbound.io || true
	@echo "Managed resources will appear here once the Crossplane manifests are applied."

crossplane-resources:
	kubectl get bucket.s3.aws.upbound.io || true
	kubectl get instance.rds.aws.upbound.io || true
	kubectl get role.iam.aws.upbound.io || true
	kubectl get table.dynamodb.aws.upbound.io || true

crossplane-watch:
	@while true; do \
		clear; \
		echo "Crossplane resource status"; \
		echo "========================"; \
		kubectl get bucket.s3.aws.upbound.io || true; \
		kubectl get instance.rds.aws.upbound.io || true; \
		kubectl get role.iam.aws.upbound.io || true; \
		kubectl get table.dynamodb.aws.upbound.io || true; \
		echo; \
		kubectl get providers.pkg.crossplane.io || true; \
		sleep 10; \
	done

crossplane-install:
	helm repo add crossplane-stable https://charts.crossplane.io/stable >/dev/null 2>&1 || true
	helm repo update >/dev/null 2>&1 || true
	helm upgrade --install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace

crossplane-status:
	kubectl get pods -n crossplane-system
	helm list -n crossplane-system || true

logs-crossplane:
	kubectl logs -n crossplane-system -l app=crossplane -f

logs-s3:
	kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws-s3 -f

logs-rds:
	kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws-rds -f

logs-iam:
	kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws-iam -f

logs-dynamodb:
	kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws-dynamodb -f

kubeconfig:
	aws eks update-kubeconfig --region $(REGION) --name $(shell terraform -chdir=terraform output -raw cluster_name 2>/dev/null)

pods:
	kubectl get pods -A -o wide

nodes:
	kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.sh/capacity-type || true

nodegroups:
	@CLUSTER=$(shell terraform -chdir=terraform output -raw cluster_name 2>/dev/null); \
	printf '%-35s %-12s %-12s %-12s %-8s %-8s %-8s\n' 'NODEGROUP' 'STATUS' 'CAPACITY' 'INSTANCE' 'MIN' 'DESIRED' 'MAX'; \
	printf '%-35s %-12s %-12s %-12s %-8s %-8s %-8s\n' '---------' '------' '--------' '--------' '---' '-------' '---'; \
	for ng in $$(aws eks list-nodegroups --region $(REGION) --cluster-name "$$CLUSTER" --query 'nodegroups[]' --output text 2>/dev/null); do \
		DATA=$$(aws eks describe-nodegroup --region $(REGION) --cluster-name "$$CLUSTER" --nodegroup-name "$$ng" --query 'nodegroup.[nodegroupName,status,capacityType,instanceTypes[0],scalingConfig.minSize,scalingConfig.desiredSize,scalingConfig.maxSize]' --output text 2>/dev/null); \
		if [ -n "$$DATA" ]; then \
			set -- $$DATA; \
			printf '%-35s %-12s %-12s %-12s %-8s %-8s %-8s\n' "$$1" "$$2" "$$3" "$$4" "$$5" "$$6" "$$7"; \
		fi; \
	done

inventory:
	@echo "== EKS clusters =="
	@aws eks list-clusters --region $(REGION) --query 'clusters' --output table || true
	@echo "== EKS nodes =="
	@kubectl get nodes -L node.kubernetes.io/instance-type,karpenter.sh/capacity-type || true
	@echo "== RDS instances =="
	@aws rds describe-db-instances --region $(REGION) --query 'DBInstances[?TagList[?Key==`crossplane-name`]].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine}' --output table || true
	@echo "== S3 buckets =="
	@aws s3api list-buckets --query 'Buckets[?contains(Name, `crossplane`)]' --output table || true
	@echo "== DynamoDB tables =="
	@aws dynamodb list-tables --region $(REGION) --query 'TableNames[?contains(@, `crossplane`)]' --output table || true

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
	cd terraform && terraform init -reconfigure -backend-config="bucket=$(BUCKET)" -backend-config="key=prod/terraform.tfstate" -backend-config="region=$(REGION)" -backend-config="encrypt=true" -backend-config="dynamodb_table=$(TABLE)"

tf-backend-create:
	@if ! command -v aws >/dev/null 2>&1; then \
		echo "AWS CLI is required but was not found in PATH"; \
		exit 1; \
	fi
	@if [ "$(REGION)" = "us-east-1" ]; then \
		aws s3api create-bucket --bucket $(BUCKET) --region $(REGION) >/dev/null 2>&1 || true; \
	else \
		aws s3api create-bucket --bucket $(BUCKET) --region $(REGION) --create-bucket-configuration LocationConstraint=$(REGION) >/dev/null 2>&1 || true; \
	fi
	aws s3api put-bucket-versioning --bucket $(BUCKET) --versioning-configuration Status=Enabled >/dev/null
	aws s3api put-bucket-encryption --bucket $(BUCKET) --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null
	aws dynamodb create-table --table-name $(TABLE) --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region $(REGION) >/dev/null 2>&1 || true
	@echo "Backend resources checked/created for bucket '$(BUCKET)'"
	@echo "Run: make tf-init"

tf-plan:
	cd terraform && terraform plan

tf-apply:
	cd terraform && terraform apply

tf-destroy:
	cd terraform && terraform destroy

tf-validate:
	cd terraform && terraform validate && tflint

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

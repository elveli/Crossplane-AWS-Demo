# Crossplane on AWS Demo

This repository contains a complete demonstration of [Crossplane](https://crossplane.io/) running on Amazon Web Services (AWS). It uses Terraform to provision the underlying EKS cluster and Helm to install Crossplane, followed by Crossplane manifests to provision AWS resources directly from Kubernetes.

> **📋 Code Review & Improvements**: See [CLAUDE.MD](./CLAUDE.MD) for detailed code analysis, security recommendations, and improvement suggestions.

## Table of Contents

- [What Does This Demo Implement?](#what-does-this-demo-implement)
- [Architecture](#architecture)
- [Benefits of Crossplane](#benefits-of-crossplane)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Cost Estimate](#cost-estimate)
- [Quick Start](#quick-start)
- [Development Setup](#development-setup)
- [Usage Guide](#usage-guide)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [FAQ](#faq)
- [Contributing](#contributing)

## What Does This Demo Implement?

This demo bridges the gap between Kubernetes and AWS by provisioning:
1. **An EKS Cluster (via Terraform):** The control plane where Crossplane lives.
2. **An S3 Bucket:** Demonstrates provisioning simple object storage.
3. **An RDS PostgreSQL Database:** Demonstrates provisioning complex, stateful infrastructure. **Why RDS?** We include RDS to showcase one of Crossplane's most powerful features: seamless secret management. When Crossplane creates the database, it automatically writes the connection details (endpoint, port, username, password) directly into a Kubernetes Secret. Your application Pods can instantly mount this secret and connect to the database without any manual hand-offs or external secret managers.
4. **An IAM Role:** Demonstrates managing cloud security and identity alongside your apps.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Account                                 │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   EKS Cluster                            │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │         Crossplane Control Plane                  │  │  │
│  │  │  ┌──────────────────────────────────────────────┐ │  │  │
│  │  │  │  Crossplane Operators                       │ │  │  │
│  │  │  │  - AWS Provider (S3, RDS, IAM, DynamoDB)  │ │  │  │
│  │  │  │  - Continuous Reconciliation Loop         │ │  │  │
│  │  │  │  - Secret Management                      │ │  │  │
│  │  │  └──────────────────────────────────────────┘ │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              │ kubectl apply -f              │
│                              ▼                               │
│  ┌────────────────┬──────────────────┬────────────────┐    │
│  │   S3 Bucket    │  RDS Database    │   IAM Role     │    │
│  │                │  (PostgreSQL)    │                │    │
│  │  (Object       │                  │  Provides      │    │
│  │   Storage)     │  + Auto Secret   │  Access        │    │
│  │                │    Management    │  Control       │    │
│  └────────────────┴──────────────────┴────────────────┘    │
│                                                             │
│  Additional Resources:                                      │
│  - DynamoDB Table (NoSQL)                                   │
│  - VPC with NAT Gateway for private subnet access           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Architecture Points:

1. **Control Plane**: EKS cluster runs Crossplane operators
2. **Data Plane**: AWS resources managed through Crossplane YAML (not direct AWS console access)
3. **Drift Detection**: Continuous reconciliation ensures desired state
4. **Secret Management**: Database credentials automatically written to Kubernetes Secrets

## Benefits of Crossplane

- **A Single API (Kubernetes):** Manage your cloud infrastructure (AWS) and your applications using the exact same Kubernetes API and tools (`kubectl`, Helm, ArgoCD).
- **Self-Service Infrastructure:** Developers can request databases, caches, or buckets by simply applying a Kubernetes YAML file, without needing to learn Terraform or wait for an infrastructure team.
- **Continuous Reconciliation:** Unlike Terraform which only checks state when you run `terraform apply`, Crossplane runs as a continuous control loop. If someone manually modifies your S3 bucket in the AWS Console, Crossplane will instantly detect the drift and revert it to the desired state.
- **No More State Files:** The Kubernetes `etcd` database acts as your state file.

## Repository Structure

- `terraform/`: Contains the Terraform code to provision an AWS VPC, an EKS cluster, and install Crossplane via Helm.
- `crossplane-manifests/`: Contains the Kubernetes YAML manifests to configure the AWS Provider and provision AWS resources (S3, RDS, IAM).

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with Administrator access
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Crossplane CLI](https://docs.crossplane.io/latest/cli/)
- [Helm](https://helm.sh/docs/intro/install/)

## Cost Estimate

Running this specific Crossplane demo on AWS will cost approximately **$0.25 per hour** (or about **$185 per month** if left running continuously) in the `us-east-1` region. If you spin it up for a 2-hour learning session and then destroy it, it will only cost you about **$0.50**.

**Breakdown of costs:**
- **EKS Control Plane:** ~$0.10 per hour (~$73.00/month)
- **EC2 Worker Nodes:** 2x `t3.medium` instances at ~$0.0416 per hour each = ~$0.083 per hour (~$60.75/month)
- **NAT Gateway:** 1 NAT Gateway at ~$0.045 per hour = ~$32.85/month
- **EBS Storage:** Default EBS volumes for worker nodes = ~$3.20/month
- **RDS PostgreSQL Instance:** 1x `db.t3.micro` instance at ~$0.018 per hour = ~$13.14/month (plus ~$2.30/month for 20GB storage)
- **S3 Bucket & IAM Role:** Negligible / Free

> **⚠️ Important:** To avoid a surprise AWS bill, **always remember to tear down the environment** as soon as you are done testing. See the [Cleanup](#cleanup) section at the bottom of this README.

## Quick Start

### 30 Second Overview

```bash
# 1. Start Crossplane (choose one)
# Option A: Docker Desktop (FREE)
helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace

# Option B: AWS EKS (~$0.25/hour)
cd terraform && terraform apply -auto-approve

# 2. Configure AWS credentials
make aws-secret

# 3. Install providers and provision resources
make aws-setup

# 4. View your resources
make aws-status
kubectl describe bucket.s3 crossplane-demo-bucket-xyz123
```

> The Makefile wraps the most common Kubernetes and Crossplane commands so you do not need to remember the full `kubectl apply -f ...` sequence every time.

---

## Step 1: Choose Your Environment

To run Crossplane, you need a Kubernetes cluster to serve as its control plane. You can choose to provision a real cluster in AWS, or run it entirely on your local machine. Choose **Option A** or **Option B** below:

### Option A: Provision EKS via Terraform (AWS)

*Use this option if you want a production-like EKS environment. This will incur AWS costs.*

Navigate to the `terraform` directory and apply the configuration:

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

Once complete, configure your local `kubectl` to connect to the new EKS cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name crossplane-demo-cluster
```

Verify Crossplane is running:

```bash
kubectl get pods -n crossplane-system
```

### Option B: Run Locally on Docker Desktop (Save Money!)

*Use this option if you want to avoid the **~$73/month** cost of running an AWS EKS control plane. Crossplane will run locally but will still successfully reach out to AWS to provision your cloud resources.*

> **💡 Key Concept:** Running Crossplane on Docker Desktop does **not** create local databases or "Docker RDS"! The Crossplane *control plane* runs on your laptop, but when you apply the manifests, it uses your AWS credentials to call the AWS API and build **real, production-ready** services (S3, RDS, DynamoDB) in the actual AWS cloud.

**1. Enable Kubernetes in Docker Desktop:**
Open Docker Desktop navigate to **Settings > Kubernetes** and check **Enable Kubernetes**. Apply and wait for the cluster to start (this takes a few minutes). 

Ensure your local `kubectl` context is set to Docker Desktop:
```bash
kubectl config use-context docker-desktop
```

**2. Install Crossplane using Helm:**
Since you aren't using the Terraform scripts (which install Crossplane automatically on EKS), you need to install it on your local cluster:
```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace
```

**3. Verify Crossplane is running:**
```bash
kubectl get pods -n crossplane-system
```

---

## Step 2: Configure AWS Credentials for Crossplane

Crossplane needs AWS credentials to provision resources. The easiest path is to use the Makefile target below, which reads your existing AWS credentials file and creates the Kubernetes secret for you:

```bash
make aws-secret
```

If you want to use a different file instead of `~/.aws/credentials`, pass it explicitly:

```bash
make aws-secret-file FILE=./creds.conf
```

If you prefer to create the secret manually, the equivalent `kubectl` command is:

```bash
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=$HOME/.aws/credentials
```

> **⚠️ Security Warning:** `creds.conf` contains your plaintext AWS secrets. **Do not commit this file to Git.** Delete it immediately after running the command:
> ```bash
> rm creds.conf
> ```

## Step 3: Install Upbound AWS Providers

Apply the provider manifests to install the AWS S3, RDS, and IAM providers:

```bash
kubectl apply -f crossplane-manifests/1-providers.yaml
```

Wait for the providers to become healthy:

```bash
kubectl get providers
```

Apply the ProviderConfig to tell the providers to use the secret we created:

```bash
kubectl apply -f crossplane-manifests/2-providerconfig.yaml
```

## Step 4: Provision AWS Resources via Crossplane

Now you can provision AWS resources using standard Kubernetes manifests. The cleanest way is to let the Makefile apply the full sequence for you:

```bash
make aws-db-secret PASSWORD=SuperSecret123!
make aws-setup
```

The `make aws-setup` target applies these manifests in order:

- S3 bucket: `crossplane-manifests/3-s3-bucket.yaml`
- RDS PostgreSQL instance: `crossplane-manifests/4-rds-instance.yaml`
- IAM role: `crossplane-manifests/5-iam-role.yaml`
- DynamoDB table: `crossplane-manifests/6-dynamodb-table.yaml`

If you prefer the raw `kubectl` form, the equivalent commands are:

```bash
kubectl apply -f crossplane-manifests/3-s3-bucket.yaml
kubectl create secret generic db-password --from-literal=password=SuperSecret123!
kubectl apply -f crossplane-manifests/4-rds-instance.yaml
kubectl apply -f crossplane-manifests/5-iam-role.yaml
kubectl apply -f crossplane-manifests/6-dynamodb-table.yaml
```

## Step 5: Useful Crossplane & Kubectl Commands

> **💡 The Magic of a Universal API:**
> One of the core benefits of Crossplane is that the control plane is entirely decoupled from the resources it manages. **Every single command below works exactly the same** whether your control plane is running on a massive AWS EKS cluster or locally on Docker Desktop! 
> *(If using Docker Desktop, just ensure you are using the local context: `kubectl config use-context docker-desktop`)*

**Checking Overall Crossplane Health & Status:**
Open-source Crossplane does not have a built-in web UI or a single health check URL. Instead, it operates natively within Kubernetes. You check its "overall" health by querying the Kubernetes API:

```bash
# 1. Check if the core Crossplane pods are running
kubectl get pods -n crossplane-system

# 2. Check if all installed Providers (like AWS) are healthy and ready
kubectl get providers

# 3. View the status of ALL infrastructure resources managed by Crossplane
kubectl get managed
```
If `READY` is `True` and `SYNCED` is `True` for your providers and managed resources, your Crossplane environment is healthy.

**Viewing the Generated RDS Secret:**
Crossplane automatically writes the RDS connection details to a Kubernetes secret. *(Note: RDS instances take 5-10 minutes to provision in AWS. The secret will not be fully populated with the endpoint and password until the instance status is `READY=True`)*.

You can view and decode it using `kubectl`:
```bash
# First, check if the RDS instance is ready
kubectl get instances.rds.aws.upbound.io

# View all keys in the secret to see what Crossplane populated
kubectl get secret crossplane-demo-db-conn -n default -o yaml

# Decode and view the actual database password
kubectl get secret crossplane-demo-db-conn -n default -o jsonpath='{.data.password}' | base64 --decode
```

**Check specific resources:**
```bash
kubectl get buckets.s3.aws.upbound.io
kubectl get instances.rds.aws.upbound.io
```

**Describe a resource to see events and status conditions:**
```bash
kubectl describe bucket.s3 crossplane-demo-bucket-xyz123
```

## Troubleshooting & Logs

**1. Viewing and Describing Crossplane Pods**
Crossplane and its providers run as standard Kubernetes Pods in the `crossplane-system` namespace. If something isn't working, checking their status, events, and logs is the best place to look:

```bash
# First, list all the Crossplane pods to get their exact names:
kubectl get pods -n crossplane-system

# Describe a specific pod to see its events, state, and configuration:
kubectl describe pod <pod-name> -n crossplane-system

# View logs for the core Crossplane controller:
kubectl logs -n crossplane-system -l app=crossplane

# View logs for a specific AWS Provider pod:
kubectl logs -n crossplane-system <provider-aws-pod-name>
```

**2. Validating AWS Credentials in Kubernetes**
If your resources are failing with an AWS credentials error (e.g., `STS: GetCallerIdentity ... InvalidClientTokenId`), you can validate exactly what credentials Crossplane sees inside its Kubernetes Secret:

```bash
# 1. Check if the secret exists
kubectl get secret aws-creds -n crossplane-system

# 2. Extract and decode the credentials Crossplane is using
kubectl get secret aws-creds -n crossplane-system -o jsonpath='{.data.creds}' | base64 --decode

# 3. (Optional) Save to a file and validate them with the AWS CLI to ensure they are active
kubectl get secret aws-creds -n crossplane-system -o jsonpath='{.data.creds}' | base64 --decode > test-creds.temp
AWS_SHARED_CREDENTIALS_FILE=test-creds.temp aws sts get-caller-identity
rm test-creds.temp
```

**What to do if `aws sts get-caller-identity` succeeds but Crossplane still fails with `InvalidClientTokenId`:**
This usually happens because the Crossplane Provider Pod has *cached* a previous, invalid version of your AWS credentials, or the secret was updated but the Pod hasn't picked up the new values yet. 

Restart the provider pods to force them to read the newest credentials:
```bash
kubectl delete pods -n crossplane-system --all
```
*(Wait a minute for the pods to recreate, and Crossplane will automatically retry the connection!)*

**What to do if `aws sts get-caller-identity` FAILS with `InvalidClientTokenId`:**
This means the credentials stored in the `aws-creds` Kubernetes secret are genuinely invalid, expired, or incomplete. This frequently happens if you are using temporary AWS credentials (e.g., from AWS SSO or `aws sts assume-role`) but forgot to include the session token.

1. Create a fresh `aws-credentials.txt` file. If using temporary credentials, you **must** include the `aws_session_token`:
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
aws_session_token = YOUR_SESSION_TOKEN_IF_APPLICABLE
```

2. Recreate the secret in your cluster:
```bash
kubectl delete secret aws-creds -n crossplane-system
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./aws-credentials.txt
```

3. Restart the Provider Pods to pick up the new secret immediately:
```bash
kubectl delete pods -n crossplane-system --all
```

**3. Fixing `crossplane top` (Metrics Server Error)**
If you try to run `crossplane top` and get an error about `metrics-server`, it's because AWS EKS does not install the Kubernetes Metrics Server by default. You can install it with one command:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
Wait about 60 seconds for it to start collecting data, and then `crossplane top` will work perfectly!

**3. Viewing Logs for AWS Resources (S3, RDS, IAM)**
It is important to understand that Crossplane provisions **real AWS managed services**, not Kubernetes Pods. 
- Because an RDS database or S3 bucket is not a Pod, **you cannot run `kubectl logs` on them.**
- To view the actual database logs or S3 access logs, you must log into the **AWS Console** and use **AWS CloudWatch**.
- However, to see what *Crossplane* is doing to those resources (e.g., update attempts, sync errors), you use:
  ```bash
  # List all AWS resources managed by Crossplane
  kubectl get managed
  
  # View Crossplane's event log for a specific resource
  kubectl describe instance.rds.aws.upbound.io crossplane-demo-db
  ```

**4. Understanding and Managing Provider Pods (e.g., `upbound-provider-family-aws`)**
If you see a pod named `upbound-provider-family-aws-...`, this is the core AWS authentication and configuration controller. 

Because AWS has hundreds of services, a single monolithic AWS provider would consume gigabytes of RAM. To fix this, Upbound splits the AWS provider into a **"family" provider** (which handles AWS credentials and shared logic) and smaller **service-specific providers** (like S3, RDS, IAM) to save memory.

**How to view them:**
```bash
# View the high-level Provider resources
kubectl get providers

# View the specific versions installed
kubectl get providerrevisions
```

**How to manipulate them:**
You generally do not edit these pods directly. Instead, you manipulate them through Crossplane Custom Resources:
- **Change Credentials/Config:** Edit the `ProviderConfig` (e.g., `kubectl edit providerconfig default`).
- **Upgrade/Change Version:** Edit the `Provider` resource (e.g., `kubectl edit provider provider-family-aws`).
- **Restart a stuck provider:** If a provider is hung or acting weird, simply delete the pod and Kubernetes will instantly recreate it:
  ```bash
  kubectl delete pod -n crossplane-system -l pkg.crossplane.io/provider=provider-family-aws
  ```

**5. How are these AWS resources actually created? Crossplane or Terraform?**
When you apply a manifest like `4-rds-instance.yaml`, **Crossplane** is the orchestrator that intercepts the Kubernetes request. However, if you describe a failing resource, you might notice error messages mentioning "Terraform" in the logs (e.g., `cannot initialize the Terraform plugin SDK`).

Here is how it works under the hood when using the official Upbound AWS Providers:
- **No `terraform` CLI or `.tf` files are used.** You do not write or execute any Terraform code to provision these specific AWS resources.
- Instead, the Upbound AWS Provider is built dynamically using a framework that wraps the official HashiCorp Terraform AWS SDK. It embeds the Terraform logic natively into the Golang provider to handle the actual API calls to AWS without running the Terraform CLI.
- So, Crossplane relies on the mature, battle-tested Terraform Provider SDK **under the hood** to communicate with AWS, but from your perspective as a user, you only ever write Kubernetes YAML manifests and Crossplane fully abstracts away the Terraform state and lifecycle!

## Development Setup

### Local Development with Docker Desktop

```bash
# 1. Clone this repository
git clone https://github.com/yourusername/Crossplane-AWS-Demo.git
cd Crossplane-AWS-Demo

# 2. Install dependencies (frontend)
npm install

# 3. Run the dev server locally
npm run dev
# Open http://localhost:3000

# 4. Enable Kubernetes on Docker Desktop
# Settings > Kubernetes > ✓ Enable Kubernetes > Apply

# 5. Install Crossplane on your local cluster
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace

# 6. Configure AWS credentials
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=$HOME/.aws/credentials
```

### Project Structure

```
src/
  ├── App.tsx            # Main React component with file tree UI
  ├── main.tsx           # React entry point
  └── index.css          # Tailwind styles
terraform/
  ├── main.tf            # VPC & EKS cluster definition
  ├── providers.tf       # Terraform provider config
  └── variables.tf       # Variable definitions
crossplane-manifests/
  ├── 1-providers.yaml           # AWS provider installation
  ├── 2-providerconfig.yaml      # AWS credentials configuration
  ├── 3-s3-bucket.yaml           # S3 bucket resource
  ├── 4-rds-instance.yaml        # RDS PostgreSQL database
  ├── 5-iam-role.yaml            # IAM role
  └── 6-dynamodb-table.yaml      # DynamoDB table
```

### Available Scripts

```bash
npm run dev      # Start Vite dev server (port 3000)
npm run build    # Build for production
npm run preview  # Preview production build locally
npm run clean    # Remove dist directory
npm run lint     # Type-check with TypeScript
```

---

## Usage Guide

### Understanding the Frontend UI

The interactive file browser displays all configuration files:
- **Left Sidebar**: File tree with collapsible folders for `terraform/` and `crossplane-manifests/`
- **Top Tab**: Currently selected file name
- **Main Area**: File contents with syntax highlighting

### Common Tasks

#### Provision S3 Bucket
```bash
kubectl apply -f crossplane-manifests/3-s3-bucket.yaml
kubectl get bucket.s3
```

#### Provision RDS Database
```bash
# Create the DB password secret first
kubectl create secret generic db-password --from-literal=password=YourSecurePassword123!

# Apply the RDS manifest
kubectl apply -f crossplane-manifests/4-rds-instance.yaml

# Check status (takes 5-10 minutes)
kubectl get instance.rds
kubectl describe instance.rds crossplane-demo-db

# View auto-generated connection secret
kubectl get secret crossplane-demo-db-conn -o yaml
```

#### Access Database Connection Details
```bash
# Get hostname/endpoint
kubectl get secret crossplane-demo-db-conn -o jsonpath='{.data.endpoint}' | base64 --decode

# Get username
kubectl get secret crossplane-demo-db-conn -o jsonpath='{.data.username}' | base64 --decode

# Get password
kubectl get secret crossplane-demo-db-conn -o jsonpath='{.data.password}' | base64 --decode

# Connect with psql
psql -h $(kubectl get secret crossplane-demo-db-conn -o jsonpath='{.data.endpoint}' | base64 --decode) \
     -U postgresadmin -d postgres
```

#### Scale Resources
```bash
# Modify the RDS instance class
kubectl patch instance.rds crossplane-demo-db --type merge \
  -p '{"spec":{"forProvider":{"instanceClass":"db.t3.small"}}}'

# Crossplane will reconcile the change automatically
```

---

## FAQ

### Q: Can I use Crossplane in production?
**A:** Yes! Crossplane is production-ready and used by organizations managing thousands of resources. Start with non-critical resources to build confidence.

### Q: How does Crossplane differ from Terraform?
**A:** 
- **Terraform**: Imperative, state-based, manual apply/destroy cycles
- **Crossplane**: Declarative, etcd-based, continuous reconciliation, GitOps-friendly

Both are complementary. This demo uses Terraform to provision *the control plane* and Crossplane to manage *the resources*.

### Q: What if I accidentally delete a resource in AWS Console?
**A:** Crossplane's reconciliation loop will automatically recreate it within seconds! This is drift detection in action.

### Q: Can I use multiple AWS accounts?
**A:** Yes. Create multiple `ProviderConfig` resources with different credentials, then reference them in your manifests:
```yaml
providerConfigRef:
  name: staging  # Different AWS account
```

### Q: How do I delete resources without deleting the manifests?
**A:** Use Crossplane's deletion policy:
```yaml
spec:
  deletionPolicy: Orphan  # Deletes K8s resource but keeps AWS resource
```

### Q: Is my AWS bill really that high?
**A:** Yes, EKS control plane is ~$73/month. For learning, use Docker Desktop (free). For prod, use EKS for HA and auto-scaling.

### Q: Can I use this with ArgoCD for GitOps?
**A:** Absolutely! Push your manifests to a Git repo, and ArgoCD will sync them to your cluster. This is the recommended setup for production.

### Q: What about secrets management?
**A:** This demo uses `kubectl create secret` for simplicity. In production, use:
- AWS Secrets Manager with [External Secrets Operator](https://external-secrets.io/)
- HashiCorp Vault
- Sealed Secrets or similar encryption

---

## Contributing

Contributions are welcome! Here's how you can help:

### Report Issues
1. Check if the issue already exists
2. Provide exact error messages and logs
3. Include your environment (OS, Kubernetes version, Terraform version)

### Propose Improvements
- See [CLAUDE.MD](./CLAUDE.MD) for detailed code analysis and improvement suggestions
- Areas for contribution:
  - [ ] Add E2E tests
  - [ ] Improve error handling in App.tsx
  - [ ] Add multi-region support
  - [ ] Create Docker container for frontend
  - [ ] Add GitHub Actions CI/CD
  - [ ] Improve documentation

### Development Workflow
```bash
git clone https://github.com/yourusername/Crossplane-AWS-Demo.git
git checkout -b feature/your-improvement
npm install
npm run lint
npm run build
# Make your changes
git push origin feature/your-improvement
# Create a Pull Request
```

### Commit Message Guidelines
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `test:` Tests
- `style:` Code style
- `refactor:` Code refactoring

---

## Cleanup

First, delete the Crossplane managed resources:
```bash
kubectl delete -f crossplane-manifests/6-dynamodb-table.yaml
kubectl delete -f crossplane-manifests/5-iam-role.yaml
kubectl delete -f crossplane-manifests/4-rds-instance.yaml
kubectl delete -f crossplane-manifests/3-s3-bucket.yaml
```

Wait for them to be deleted (Crossplane will delete the actual AWS resources).

Then, if you provisioned the EKS cluster using Terraform (Step 1), destroy the infrastructure:
```bash
cd terraform
terraform destroy -auto-approve
```
*(If you ran this locally on Docker Desktop, simply uninstall the Helm release from your local cluster instead: `helm uninstall crossplane --namespace crossplane-system`)*

---

## Resources & Further Learning

### Official Documentation
- [Crossplane Docs](https://docs.crossplane.io/) - Official documentation
- [Upbound AWS Provider Docs](https://marketplace.upbound.io/providers/upbound/provider-aws) - AWS-specific resources
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) - Reference for all AWS resources
- [Kubernetes Documentation](https://kubernetes.io/docs/) - Kubernetes basics

### Tutorials & Articles
- [Crossplane 101](https://docs.crossplane.io/latest/getting-started/introduction/) - Getting started guide
- [Crossplane GitOps Guide](https://docs.crossplane.io/latest/guides/vault-secret-injection/) - Using Crossplane with GitOps tools
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/) - EKS recommendations

### Community
- [Crossplane Slack](https://slack.crossplane.io/) - Community chat
- [GitHub Issues](https://github.com/crossplane/crossplane/issues) - Report bugs and request features
- [CNCF Community](https://www.cncf.io/) - Cloud Native Computing Foundation

### Tools Used
- [Terraform](https://terraform.io/) - Infrastructure as Code
- [Kubernetes](https://kubernetes.io/) - Container orchestration
- [Helm](https://helm.sh/) - Kubernetes package manager
- [React](https://react.dev/) - UI framework
- [Vite](https://vitejs.dev/) - Frontend build tool
- [Tailwind CSS](https://tailwindcss.com/) - Utility-first CSS

---

## Support & Feedback

- **Questions?** Check the [FAQ](#faq) section or open a [GitHub Discussion](https://github.com/issues)
- **Found a bug?** [Create an Issue](https://github.com/issues)
- **Want to contribute?** See the [Contributing](#contributing) section
- **Code Review?** See [CLAUDE.MD](./CLAUDE.MD) for detailed analysis and suggestions

---

## License

This project is provided as-is for educational purposes. Please refer to individual component licenses:
- Terraform configuration: Generally public domain for educational use
- React frontend: Licensed under the MIT License (see package.json)
- Crossplane and providers: Licensed under the Apache 2.0 License

**⚠️ Important:** AWS resources provisioned by this demo **are not free**. Review the [Cost Estimate](#cost-estimate) section before running. AWS will bill you for all provisioned resources.

---

**Last Updated:** June 2026 | **Created by:** Google AI Studio | **Reviewed by:** GitHub Copilot

---

## Quick Reference Cheat Sheet

```bash
# Cluster operations
kubectl config use-context docker-desktop        # Switch to local
kubectl config use-context crossplane-demo-cluster # Switch to EKS
kubectl get nodes -o wide                        # View cluster nodes

# Crossplane operations
kubectl get providers                            # List installed providers
kubectl get managed                              # List all managed resources
kubectl get <resource-type>                      # Get specific resource type
kubectl describe <resource> <name>               # View resource details
kubectl delete <resource> <name>                 # Delete resource
kubectl logs -n crossplane-system <pod-name>    # View provider logs

# Resource inspection
kubectl get secret <name> -o yaml               # View secret (base64 encoded)
kubectl get secret <name> -o jsonpath='{.data.key}' | base64 --decode  # Decode secret value

# Terraform operations
terraform init                                  # Initialize Terraform
terraform plan                                  # Preview changes
terraform apply -auto-approve                   # Apply without confirmation
terraform destroy -auto-approve                 # Destroy all resources
```

---



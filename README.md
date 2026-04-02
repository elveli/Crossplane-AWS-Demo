# Crossplane on AWS Demo

This repository contains a complete demonstration of [Crossplane](https://crossplane.io/) running on Amazon Web Services (AWS). It uses Terraform to provision the underlying EKS cluster and Helm to install Crossplane, followed by Crossplane manifests to provision AWS resources directly from Kubernetes.

## What Does This Demo Implement?

This demo bridges the gap between Kubernetes and AWS by provisioning:
1. **An EKS Cluster (via Terraform):** The control plane where Crossplane lives.
2. **An S3 Bucket:** Demonstrates provisioning simple object storage.
3. **An RDS PostgreSQL Database:** Demonstrates provisioning complex, stateful infrastructure. **Why RDS?** We include RDS to showcase one of Crossplane's most powerful features: seamless secret management. When Crossplane creates the database, it automatically writes the connection details (endpoint, port, username, password) directly into a Kubernetes Secret. Your application Pods can instantly mount this secret and connect to the database without any manual hand-offs or external secret managers.
4. **An IAM Role:** Demonstrates managing cloud security and identity alongside your apps.

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

## Step 1: Provision EKS and Install Crossplane

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

## Step 2: Configure AWS Credentials for Crossplane

Crossplane needs AWS credentials to provision resources. Create a temporary `creds.conf` file in your **current directory** (the root of this project) with your AWS credentials:

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

*(Note: You can also just point to your existing AWS credentials file in the next step if you prefer).*

Create a Kubernetes secret in the `crossplane-system` namespace using this file:

```bash
# If using the local creds.conf file:
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./creds.conf

# OR, if using your existing AWS credentials file:
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=$HOME/.aws/credentials
```

> **⚠️ Security Warning:** `creds.conf` contains your plaintext AWS secrets. **Do not commit this file to Git.** Delete it immediately after running the command above:
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

Now you can provision AWS resources using standard Kubernetes manifests!

**1. Create an S3 Bucket:**
```bash
kubectl apply -f crossplane-manifests/3-s3-bucket.yaml
```

**2. Create an RDS PostgreSQL Instance:**
```bash
# Note: You must create a secret for the DB password first
kubectl create secret generic db-password --from-literal=password=SuperSecret123!
kubectl apply -f crossplane-manifests/4-rds-instance.yaml
```

**3. Create an IAM Role:**
```bash
kubectl apply -f crossplane-manifests/5-iam-role.yaml
```

**4. Create a DynamoDB Table (Provisions in seconds!):**
```bash
kubectl apply -f crossplane-manifests/6-dynamodb-table.yaml
```

## Step 5: Useful Crossplane & Kubectl Commands

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

**Use the Crossplane CLI to trace a resource and see its full dependency tree and status:**
```bash
crossplane beta trace bucket.s3.aws.upbound.io crossplane-demo-bucket-xyz123
crossplane beta trace instance.rds.aws.upbound.io crossplane-demo-db
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

**2. Fixing `crossplane beta top` (Metrics Server Error)**
If you try to run `crossplane beta top` and get an error about `metrics-server`, it's because AWS EKS does not install the Kubernetes Metrics Server by default. You can install it with one command:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
Wait about 60 seconds for it to start collecting data, and then `crossplane beta top` will work perfectly!

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

## Cleanup

First, delete the Crossplane managed resources:
```bash
kubectl delete -f crossplane-manifests/6-dynamodb-table.yaml
kubectl delete -f crossplane-manifests/5-iam-role.yaml
kubectl delete -f crossplane-manifests/4-rds-instance.yaml
kubectl delete -f crossplane-manifests/3-s3-bucket.yaml
```

Wait for them to be deleted (Crossplane will delete the actual AWS resources).

Then, destroy the Terraform infrastructure:
```bash
cd terraform
terraform destroy -auto-approve
```

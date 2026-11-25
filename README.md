# Crossplane on AWS Demo

A hands-on demo of [Crossplane](https://crossplane.io/): you write Kubernetes YAML, and Crossplane creates real AWS resources (S3, RDS PostgreSQL, IAM, DynamoDB) and keeps them in the declared state.

You can run the Crossplane control plane **locally on Docker Desktop** (cheapest, ~5 minutes) or on **AWS EKS provisioned with Terraform** (production-like). See [Choose Your Path](#choose-your-path).

> **📋 Code Review & Improvements**: See [CLAUDE.MD](./CLAUDE.MD) for detailed code analysis, security recommendations, and improvement suggestions.

## Table of Contents

- [What Does This Demo Implement?](#what-does-this-demo-implement)
- [Architecture](#architecture)
- [Benefits of Crossplane](#benefits-of-crossplane)
- [Choose Your Path](#choose-your-path): **Local (Docker Desktop)** or **AWS (EKS)**
- [Prerequisites](#prerequisites)
- [Cost Estimate](#cost-estimate)
- [Path A: Local Control Plane on Docker Desktop](#path-a-local-control-plane-on-docker-desktop)
- [Path B: AWS Control Plane on EKS (Terraform)](#path-b-aws-control-plane-on-eks-terraform)
- [Shared Steps (Both Paths)](#shared-steps-both-paths)
- [Exploring Your Resources](#exploring-your-resources)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Frontend: Interactive File Browser](#frontend-interactive-file-browser) (runs in Docker)
- [Makefile Command Reference](#makefile-command-reference)
- [Repository Structure](#repository-structure)
- [FAQ](#faq)
- [Contributing](#contributing)

## What Does This Demo Implement?

This demo bridges the gap between Kubernetes and AWS:
1. **A Crossplane control plane**, either on Docker Desktop (local) or on an EKS cluster provisioned by Terraform.
2. **An S3 Bucket:** Demonstrates provisioning simple object storage.
3. **An RDS PostgreSQL Database:** Demonstrates provisioning complex, stateful infrastructure. **Why RDS?** We include RDS to showcase one of Crossplane's most powerful features: seamless secret management. When Crossplane creates the database, it automatically writes the connection details (endpoint, port, username, password) directly into a Kubernetes Secret. Your application Pods can instantly mount this secret and connect to the database without any manual hand-offs or external secret managers.
4. **An IAM Role:** Demonstrates managing cloud security and identity alongside your apps.
5. **A DynamoDB Table:** Demonstrates a serverless, pay-per-request NoSQL resource.

## Architecture

```text
 Developer workstation
 +---------------------------------------------------------------------+
 |  (1) terraform apply                (2) make aws-setup              |
 |      terraform/*.tf                     kubectl apply -f            |
 |                                         crossplane-manifests/       |
 +-------------|--------------------------------------|----------------+
               | provisions                           | desired state
               v                                      v
 +---------------------------------------------------------------------+
 | AWS Account (us-east-1)                                             |
 |                                                                     |
 |  VPC 10.0.0.0/16 - 3 AZs, public + private subnets, 1 NAT Gateway   |
 |  +---------------------------------------------------------------+  |
 |  | EKS cluster "crossplane-demo-cluster" (Kubernetes 1.31)       |  |
 |  | Managed node group: 2-4 x t3/t3a/t2.medium (Spot)             |  |
 |  |                                                               |  |
 |  |  namespace: default                                           |  |
 |  |   Secret "db-password"             -> RDS master password     |  |
 |  |   Secret "crossplane-demo-db-conn" <- RDS endpoint/user/pass  |  |
 |  |                                       (written by Crossplane) |  |
 |  |                                                               |  |
 |  |  namespace: crossplane-system                                 |  |
 |  |  +---------------------------------------------------------+  |  |
 |  |  | Crossplane 1.15 (Helm)                                  |  |  |
 |  |  |  Providers: aws-s3 | aws-rds | aws-iam | aws-dynamodb   |  |  |
 |  |  |  ProviderConfig "default"  <--  Secret "aws-creds"      |  |  |
 |  |  +----------------------------+----------------------------+  |  |
 |  +-------------------------------|-------------------------------+  |
 |                                  | continuous reconcile             |
 |                                  | (create / update / fix drift)    |
 |        +--------------+----------+---+-------------+                |
 |        v              v              v             v                |
 |  +-----------+ +-------------+ +-----------+ +-----------+          |
 |  | S3 Bucket | | RDS         | | IAM Role  | | DynamoDB  |          |
 |  |           | | PostgreSQL  | |           | | Table     |          |
 |  |           | | 16          | |           | |           |          |
 |  |           | | db.t3.micro | |           | |           |          |
 |  +-----------+ +-------------+ +-----------+ +-----------+          |
 |                                                                     |
 +---------------------------------------------------------------------+

 Teardown: make teardown -> kubectl delete (managed resources first),
           then terraform destroy (EKS, VPC, NAT Gateway)
```

> The diagram shows **Path B (AWS)**. On **Path A (Local)**, the VPC and EKS boxes are replaced by Docker Desktop on your laptop. Everything inside the cluster, and every AWS resource below it, stays the same.

### Key Architecture Points:

1. **Bootstrap (Terraform)**: Provisions the VPC, EKS cluster, Spot node group, and installs Crossplane via Helm
2. **Control Plane (Crossplane)**: Runs inside EKS with one Upbound provider per AWS service (S3, RDS, IAM, DynamoDB)
3. **Managed Resources (YAML)**: AWS resources are declared as Kubernetes manifests and created through `kubectl apply`, not the AWS console
4. **Drift Detection**: Continuous reconciliation reverts manual changes back to the desired state
5. **Secret Management**: RDS connection details are written back into the `crossplane-demo-db-conn` Kubernetes Secret

## Benefits of Crossplane

- **A Single API (Kubernetes):** Manage your cloud infrastructure (AWS) and your applications using the exact same Kubernetes API and tools (`kubectl`, Helm, ArgoCD).
- **Self-Service Infrastructure:** Developers can request databases, caches, or buckets by simply applying a Kubernetes YAML file, without needing to learn Terraform or wait for an infrastructure team.
- **Continuous Reconciliation:** Unlike Terraform which only checks state when you run `terraform apply`, Crossplane runs as a continuous control loop. If someone manually modifies your S3 bucket in the AWS Console, Crossplane will instantly detect the drift and revert it to the desired state.
- **No More State Files:** The Kubernetes `etcd` database acts as your state file.

## Choose Your Path

Crossplane needs a Kubernetes cluster to run on. That cluster is only the **control plane**: wherever it runs, the S3 bucket, RDS database, IAM role and DynamoDB table are always created as **real resources in your AWS account**.

You pick where the control plane runs:

| | **Path A: Local (Docker Desktop)** | **Path B: AWS (EKS via Terraform)** |
|---|---|---|
| Where Crossplane runs | Kubernetes built into Docker Desktop on your laptop | EKS cluster in your AWS account |
| What gets created in AWS | S3, RDS, IAM role, DynamoDB | Same, **plus** VPC, NAT Gateway, EKS cluster, Spot nodes |
| Approx. cost | ~$0.02/hour (mostly RDS) | ~$0.25/hour |
| Time to a running cluster | ~5 minutes | ~15-20 minutes |
| Needs Terraform | No | Yes |
| Best for | Learning Crossplane, quick demos | Production-like setup, learning EKS too |

> **💡 Not sure? Start with Path A.** Every Crossplane step after the cluster setup is identical, so you can move to Path B later without relearning anything.

```text
 Path A: Local                          Path B: AWS
 +-------------------------------+      +-------------------------------+
 | A1. Enable Kubernetes in      |      | B1. terraform apply           |
 |     Docker Desktop            |      |     (VPC, EKS, Crossplane)    |
 | A2. make crossplane-install   |      | B2. make kubeconfig           |
 +---------------+---------------+      +---------------+---------------+
                 |                                      |
                 +------------------+-------------------+
                                    v
              +-------------------------------------------+
              | Shared steps (same commands for both)     |
              |  1. make aws-secret       AWS credentials |
              |  2. make aws-db-secret    RDS password    |
              |  3. make aws-setup        providers + AWS |
              |  4. make crossplane-watch wait for READY  |
              +---------------------+---------------------+
                                    v
              +-------------------------------------------+
              | Cleanup (per path, see below)             |
              +-------------------------------------------+
```

## Prerequisites

| Tool | Path A (Local) | Path B (AWS) |
|---|:---:|:---:|
| [AWS account](https://aws.amazon.com/) + [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) with credentials in `~/.aws/credentials` | ✅ | ✅ |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | ✅ | ✅ |
| [Helm](https://helm.sh/docs/intro/install/) | ✅ | ✅ |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) (with Kubernetes enabled) | ✅ | optional (frontend only) |
| [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0 | | ✅ |
| [Crossplane CLI](https://docs.crossplane.io/latest/cli/) | optional | optional |

The AWS credentials need permission to create S3, RDS, IAM and DynamoDB resources (Path A), plus VPC, EC2 and EKS resources (Path B).

## Cost Estimate

Prices are for `us-east-1`. **Both paths create billable AWS resources**, so always run [Cleanup](#cleanup) when you are done.

**Path A: Local** (about **$0.02/hour**)
- **RDS PostgreSQL** `db.t3.micro`: ~$0.018/hour, plus ~$2.30/month for 20 GB storage
- **S3, IAM role, DynamoDB** (pay-per-request): negligible at demo scale
- **Control plane:** free, it runs on your laptop

**Path B: AWS** (about **$0.25/hour**, or ~$185/month if left running)
- Everything in Path A, plus:
- **EKS control plane:** ~$0.10/hour (~$73/month)
- **Worker nodes:** 2x `t3.medium`-class instances. At on-demand prices that is ~$0.083/hour; the node group uses **Spot**, which is usually considerably cheaper
- **NAT Gateway:** ~$0.045/hour (~$32.85/month)
- **EBS volumes** for the nodes: ~$3.20/month

A 2-hour learning session on Path B costs roughly **$0.50**.

---

## Path A: Local Control Plane on Docker Desktop

Crossplane runs on your laptop and calls the AWS API with your credentials. No EKS, VPC or Terraform is involved.

> **💡 Key concept:** This does **not** create local databases or a "Docker RDS". Only the Crossplane *control plane* runs locally; the S3 bucket, RDS instance and so on are created in the **real AWS cloud**.

### A1. Enable Kubernetes in Docker Desktop

1. Open Docker Desktop → **Settings → Kubernetes**.
2. Check **Enable Kubernetes**, then **Apply & Restart**. Wait until the status shows Kubernetes as running (a few minutes).
3. Point `kubectl` at the local cluster and check it responds:

```bash
kubectl config use-context docker-desktop
kubectl get nodes
```

### A2. Install Crossplane with Helm

On Path B, Terraform installs Crossplane for you. Locally, you install it yourself:

```bash
make crossplane-install
make crossplane-status     # crossplane + crossplane-rbac-manager pods should be Running
```

<details>
<summary>Equivalent raw commands</summary>

```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system --create-namespace
kubectl get pods -n crossplane-system
```
</details>

✅ **Done.** Continue with the [Shared Steps](#shared-steps-both-paths).

---

## Path B: AWS Control Plane on EKS (Terraform)

Terraform creates a VPC, an EKS cluster with Spot worker nodes, and installs Crossplane on it with Helm.

### B1. Provision EKS with Terraform

```bash
cd terraform
terraform init
terraform apply        # review the plan, then type "yes"; takes ~15-20 minutes
cd ..
```

> **Note:** [terraform/backend.tf](terraform/backend.tf) stores state in an S3 bucket. Create the bucket and lock table first with `make tf-backend-create`, or remove `backend.tf` to keep state locally.

### B2. Connect kubectl to the cluster

```bash
make kubeconfig            # runs: aws eks update-kubeconfig --name crossplane-demo-cluster
make crossplane-status     # crossplane + crossplane-rbac-manager pods should be Running
```

✅ **Done.** Continue with the [Shared Steps](#shared-steps-both-paths).

---

## Shared Steps (Both Paths)

From here on, **every command is identical** whether Crossplane runs on Docker Desktop or EKS. `kubectl` just talks to whichever cluster your current context points at:

```bash
kubectl config current-context   # docker-desktop (Path A) or the EKS cluster ARN (Path B)
```

### Step 1: Give Crossplane your AWS credentials

Crossplane reads AWS credentials from the Kubernetes Secret `aws-creds` in `crossplane-system`:

```bash
make aws-secret                              # uses ~/.aws/credentials
# or, from a different file:
make aws-secret-file FILE=./creds.conf
```

> **⚠️ Temporary credentials (SSO / assume-role):** the file must include `aws_session_token`, and the secret has to be refreshed when the session expires. See [Troubleshooting](#troubleshooting).
>
> **⚠️ Never commit a credentials file to Git.** Delete any copy such as `creds.conf` after creating the secret.

### Step 2: Create the RDS master password

The RDS manifest reads its password from the Secret `db-password`. Create it **before** applying the manifests:

```bash
make aws-db-secret PASSWORD='SuperSecret123!'
```

### Step 3: Install providers and provision AWS resources

```bash
make aws-setup
```

This single target:

1. Installs the Upbound AWS providers (`1-providers.yaml`) and **waits** until they are healthy (up to 10 min)
2. Applies the `ProviderConfig` that points them at `aws-creds` (`2-providerconfig.yaml`)
3. Creates the AWS resources: S3 bucket, RDS PostgreSQL, IAM role, DynamoDB table (`3-` to `6-*.yaml`)

<details>
<summary>Equivalent raw commands</summary>

```bash
kubectl apply -f crossplane-manifests/1-providers.yaml
kubectl wait --for=condition=Healthy providers.pkg.crossplane.io --all --timeout=10m
kubectl apply -f crossplane-manifests/2-providerconfig.yaml
kubectl apply -f crossplane-manifests/3-s3-bucket.yaml
kubectl apply -f crossplane-manifests/4-rds-instance.yaml
kubectl apply -f crossplane-manifests/5-iam-role.yaml
kubectl apply -f crossplane-manifests/6-dynamodb-table.yaml
```
</details>

### Step 4: Watch the resources become ready

```bash
make crossplane-watch      # refreshes every 10s; Ctrl+C to stop
```

S3, IAM and DynamoDB are usually ready within a minute. **RDS takes 5-10 minutes.** Everything is healthy when `SYNCED` and `READY` are both `True`.

✅ **You now manage AWS infrastructure through Kubernetes.** Next: [explore what you built](#exploring-your-resources), and when you are finished, **[clean up](#cleanup)**.

---

## Exploring Your Resources

> These commands work the same on both paths.

**Overall Crossplane health.** Open-source Crossplane has no web UI; you check its health through the Kubernetes API:

```bash
kubectl get pods -n crossplane-system   # core + provider pods
kubectl get providers                   # INSTALLED and HEALTHY should be True
kubectl get managed                     # every AWS resource Crossplane manages
```

If `READY` is `True` and `SYNCED` is `True` for your providers and managed resources, your Crossplane environment is healthy.

**Example output (healthy environment):**
```text
$ kubectl get pods -n crossplane-system
NAME                                                        READY   STATUS    RESTARTS   AGE
crossplane-7686c8bdf8-5lvrx                                 1/1     Running   0          25m
crossplane-rbac-manager-8669d6f47b-z7vdr                    1/1     Running   0          25m
provider-aws-dynamodb-51906f5a7129-69cfd4bd75-8cvzn         1/1     Running   0          21m
provider-aws-iam-1195525b7589-7d84c5459c-pp2zv              1/1     Running   0          22m
provider-aws-rds-cffcb6120554-cb47ddbcf-6qw6g               1/1     Running   0          22m
provider-aws-s3-d17766e0e571-67466fc7c5-9rrv8               1/1     Running   0          21m
upbound-provider-family-aws-72b4e62c1086-7676846567-pn8t8   1/1     Running   0          22m

$ kubectl get providers
NAME                          INSTALLED   HEALTHY   PACKAGE                                                 AGE
provider-aws-dynamodb         True        True      xpkg.upbound.io/upbound/provider-aws-dynamodb:v1.14.0   22m
provider-aws-iam              True        True      xpkg.upbound.io/upbound/provider-aws-iam:v1.14.0        22m
provider-aws-rds              True        True      xpkg.upbound.io/upbound/provider-aws-rds:v1.14.0        23m
provider-aws-s3               True        True      xpkg.upbound.io/upbound/provider-aws-s3:v1.14.0         23m
upbound-provider-family-aws   True        True      xpkg.upbound.io/upbound/provider-family-aws:v2.6.2      22m

$ kubectl get managed
NAME                                                  SYNCED   READY   EXTERNAL-NAME           AGE
table.dynamodb.aws.upbound.io/crossplane-demo-table   True     True    crossplane-demo-table   21m

NAME                                           SYNCED   READY   EXTERNAL-NAME          AGE
role.iam.aws.upbound.io/crossplane-demo-role   True     True    crossplane-demo-role   21m

NAME                                             SYNCED   READY   EXTERNAL-NAME                   AGE
instance.rds.aws.upbound.io/crossplane-demo-db   True     True    db-F3PCKWMBTFMZVSSI3RIZJCYJWM   8m57s

NAME                                                     SYNCED   READY   EXTERNAL-NAME                   AGE
bucket.s3.aws.upbound.io/crossplane-demo-bucket-xyz123   True     True    crossplane-demo-bucket-xyz123   21m
```
`kubectl get managed` groups output by resource kind (one table per kind), which is why you see four separate headers above instead of one combined list. The `provider-*` pods are the AWS-specific controllers (S3, RDS, IAM, DynamoDB) installed by `make aws-setup`. Right after Crossplane is installed, only `crossplane` and `crossplane-rbac-manager` are present.

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

**Example output:**
```text
$ kubectl get buckets.s3.aws.upbound.io
NAME                            SYNCED   READY   EXTERNAL-NAME                   AGE
crossplane-demo-bucket-xyz123   True     True    crossplane-demo-bucket-xyz123   52m

$ kubectl get instances.rds.aws.upbound.io
NAME                 SYNCED   READY   EXTERNAL-NAME                   AGE
crossplane-demo-db   True     True    db-F3PCKWMBTFMZVSSI3RIZJCYJWM   40m
```
Note the RDS `EXTERNAL-NAME` (`db-F3PCKWMBTFMZVSSI3RIZJCYJWM`) doesn't match the bucket's, which mirrors its own resource name. That's because the RDS manifest doesn't set an explicit `identifier`, so the provider auto-generates one rather than reusing the Crossplane object name.

**Describe a resource to see events and status conditions:**
```bash
kubectl describe bucket.s3 crossplane-demo-bucket-xyz123
```

### Working with the Database

```bash
# Endpoint, username and password written by Crossplane
kubectl get secret crossplane-demo-db-conn -o jsonpath='{.data.endpoint}' | base64 --decode
kubectl get secret crossplane-demo-db-conn -o jsonpath='{.data.username}' | base64 --decode
kubectl get secret crossplane-demo-db-conn -o jsonpath='{.data.password}' | base64 --decode
```

> The instance is created with `publiclyAccessible: false`, so `psql` from your laptop won't connect. Connect from a Pod or host that has network access to the instance.

**Change a resource declaratively:** patch the manifest, and Crossplane reconciles AWS to match:

```bash
kubectl patch instance.rds crossplane-demo-db --type merge \
  -p '{"spec":{"forProvider":{"instanceClass":"db.t3.small"}}}'
```

---

## Cleanup

> **⚠️ Do this on both paths.** Even on Path A, the RDS instance and other resources live in AWS and keep billing until Crossplane deletes them. **Delete the managed resources first, while Crossplane is still running**; if you remove Crossplane or the cluster first, nothing is left to delete them and they stay running in AWS.

### Path A: Local

```bash
# 1. Delete the AWS resources (Crossplane removes them from AWS)
kubectl delete -f crossplane-manifests/6-dynamodb-table.yaml
kubectl delete -f crossplane-manifests/5-iam-role.yaml
kubectl delete -f crossplane-manifests/4-rds-instance.yaml
kubectl delete -f crossplane-manifests/3-s3-bucket.yaml

# 2. Wait until nothing is left (RDS deletion takes a few minutes)
kubectl get managed

# 3. Remove Crossplane from Docker Desktop
helm uninstall crossplane --namespace crossplane-system
```

Optionally, turn off Kubernetes in Docker Desktop afterwards (**Settings → Kubernetes**).

> Don't use `make teardown` on Path A: it also runs `terraform destroy`, which is only meant for Path B.

### Path B: AWS

```bash
make teardown
```

This deletes the Crossplane managed resources first, then runs `terraform destroy -auto-approve` to remove the EKS cluster, nodes, NAT Gateway and VPC. **There is no extra confirmation prompt.**

<details>
<summary>Equivalent raw commands</summary>

```bash
kubectl delete -f crossplane-manifests/6-dynamodb-table.yaml
kubectl delete -f crossplane-manifests/5-iam-role.yaml
kubectl delete -f crossplane-manifests/4-rds-instance.yaml
kubectl delete -f crossplane-manifests/3-s3-bucket.yaml
kubectl get managed        # wait until empty

cd terraform
terraform destroy
```
</details>

### Verify nothing is left in AWS

```bash
make inventory     # lists EKS clusters, RDS instances, S3 buckets and DynamoDB tables in us-east-1
```

---

## Troubleshooting

**0. `kubectl` is talking to the wrong cluster**
If you have used both paths, check which cluster you are on before anything else:

```bash
kubectl config current-context
kubectl config use-context docker-desktop     # Path A
make kubeconfig                               # Path B
```

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
If you try to run `crossplane top` and get an error about `metrics-server`, it's because neither EKS nor Docker Desktop installs the Kubernetes Metrics Server by default. You can install it with one command:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
Wait about 60 seconds for it to start collecting data, and then `crossplane top` will work perfectly!

**4. Viewing Logs for AWS Resources (S3, RDS, IAM)**
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

**5. Understanding and Managing Provider Pods (e.g., `upbound-provider-family-aws`)**
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

**6. How are these AWS resources actually created? Crossplane or Terraform?**
When you apply a manifest like `4-rds-instance.yaml`, **Crossplane** is the orchestrator that intercepts the Kubernetes request. However, if you describe a failing resource, you might notice error messages mentioning "Terraform" in the logs (e.g., `cannot initialize the Terraform plugin SDK`).

Here is how it works under the hood when using the official Upbound AWS Providers:
- **No `terraform` CLI or `.tf` files are used.** You do not write or execute any Terraform code to provision these specific AWS resources.
- Instead, the Upbound AWS Provider is built dynamically using a framework that wraps the official HashiCorp Terraform AWS SDK. It embeds the Terraform logic natively into the Golang provider to handle the actual API calls to AWS without running the Terraform CLI.
- So, Crossplane relies on the mature, battle-tested Terraform Provider SDK **under the hood** to communicate with AWS, but from your perspective as a user, you only ever write Kubernetes YAML manifests and Crossplane fully abstracts away the Terraform state and lifecycle!

---

## Frontend: Interactive File Browser

The repo includes a small React app that shows every Terraform file and Crossplane manifest in a browsable file tree. **It is optional and independent of both paths**: it only reads the files in this repo and never talks to your cluster or AWS.

- **Left sidebar:** file tree with collapsible `terraform/` and `crossplane-manifests/` folders
- **Top tab:** currently selected file
- **Main area:** file contents with syntax highlighting

### Option 1: Run in Docker (no Node.js needed)

| Command | What it does | URL |
|---|---|---|
| `make docker-compose` | Builds the production image and runs it via `docker-compose up` | http://localhost:3000 |
| `make docker-run` | Same, with plain `docker build` + `docker run` | http://localhost:3000 |
| `make docker-compose-dev` | Dev container with hot reload; `src/`, manifests and Terraform are mounted from your checkout | http://localhost:3000 |

The production image ([Dockerfile](Dockerfile)) is a multi-stage build: Node 20 builds the static site, which is then served with `serve` as a non-root user, with a health check.

Stop the container with `Ctrl+C` (or `docker-compose down`).

### Option 2: Run with Node.js

```bash
make npm-install   # npm install
make dev           # Vite dev server on http://localhost:3000
```

| npm script | Purpose |
|---|---|
| `npm run dev` | Vite dev server (port 3000) |
| `npm run build` | Production build into `dist/` |
| `npm run preview` | Preview the production build |
| `npm run lint` | TypeScript type-check + ESLint |
| `npm run format` | Prettier |
| `npm run clean` | Remove `dist/` |

---

## Makefile Command Reference

Run `make help` for the full list. The most useful targets:

| Area | Command | What it does |
|---|---|---|
| **Path A** | `make crossplane-install` | Install or upgrade Crossplane via Helm on the current cluster |
| **Path B** | `make tf-backend-create` | Create the S3 state bucket and DynamoDB lock table |
| | `make tf-init` / `tf-plan` / `tf-apply` | Terraform init / plan / apply |
| | `make kubeconfig` | Point `kubectl` at the EKS cluster |
| | `make nodes` / `make nodegroups` | Show nodes and EKS node groups (instance and capacity type) |
| **Shared** | `make aws-secret` | Create the `aws-creds` secret from `~/.aws/credentials` |
| | `make aws-secret-file FILE=...` | Same, from a specific file |
| | `make aws-db-secret PASSWORD=...` | Create the RDS `db-password` secret |
| | `make aws-setup` | Install providers and apply all AWS resource manifests |
| | `make crossplane-status` | Crossplane pods and Helm release |
| | `make aws-status` | Providers and ProviderConfigs |
| | `make crossplane-resources` / `crossplane-watch` | Show (or watch) the managed AWS resources |
| | `make logs-crossplane` / `logs-s3` / `logs-rds` / `logs-iam` / `logs-dynamodb` | Tail controller logs |
| | `make inventory` | Check what actually exists in AWS |
| **Cleanup** | `make teardown` | **Path B only:** delete managed resources, then `terraform destroy` |
| **Frontend** | `make docker-compose` / `docker-run` / `dev` | Run the file browser UI |

---

## Repository Structure

```
crossplane-manifests/          # Applied in order by `make aws-setup`
  ├── 1-providers.yaml         # Upbound AWS providers (S3, RDS, IAM, DynamoDB)
  ├── 2-providerconfig.yaml    # Points providers at the aws-creds secret
  ├── 3-s3-bucket.yaml         # S3 bucket
  ├── 4-rds-instance.yaml      # RDS PostgreSQL (writes crossplane-demo-db-conn secret)
  ├── 5-iam-role.yaml          # IAM role
  └── 6-dynamodb-table.yaml    # DynamoDB table
terraform/                     # Path B only
  ├── main.tf                  # VPC + EKS cluster with Spot node group
  ├── crossplane.tf            # Crossplane Helm release
  ├── backend.tf               # S3 remote state
  ├── providers.tf, variables.tf, outputs.tf
src/                           # Frontend file browser (React + Vite)
Dockerfile, Dockerfile.dev, docker-compose.yml   # Frontend containers
Makefile                       # Shortcuts for every step above
docs/                          # Development, deployment and contributing guides
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
**A:** On Path B, yes: the EKS control plane alone is ~$73/month. On Path A (Docker Desktop) the control plane is free, and you only pay for the AWS resources Crossplane creates (mostly RDS, ~$0.02/hour). Either way, run [Cleanup](#cleanup) when you are done.

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


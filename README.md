# Crossplane on AWS Demo

This repository contains a complete demonstration of [Crossplane](https://crossplane.io/) running on Amazon Web Services (AWS). It uses Terraform to provision the underlying EKS cluster and Helm to install Crossplane, followed by Crossplane manifests to provision AWS resources directly from Kubernetes.

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

Crossplane needs AWS credentials to provision resources. Create a `creds.conf` file with your AWS credentials:

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

Create a Kubernetes secret in the `crossplane-system` namespace:

```bash
kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./creds.conf
```

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

## Step 5: Useful Crossplane & Kubectl Commands

Check the status of your managed resources:
```bash
kubectl get managed
```

Check specific resources:
```bash
kubectl get buckets.s3.aws.upbound.io
kubectl get instances.rds.aws.upbound.io
```

Describe a resource to see events and status conditions:
```bash
kubectl describe bucket.s3 crossplane-demo-bucket-xyz123
```

Use the Crossplane CLI to trace a resource and see its full dependency tree and status:
```bash
crossplane beta trace bucket.s3.aws.upbound.io crossplane-demo-bucket-xyz123
```

## Cleanup

First, delete the Crossplane managed resources:
```bash
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

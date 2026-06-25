# Deployment Guide

This guide covers deploying the Crossplane AWS Demo in various environments.

## Table of Contents

- [Local Development](#local-development)
- [Docker Deployment](#docker-deployment)
- [Production Deployment](#production-deployment)
- [GitHub Actions CI/CD](#github-actions-cicd)
- [Troubleshooting](#troubleshooting)

---

## Local Development

### Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Start development server
npm run dev

# 3. Open http://localhost:5173 (Vite) or http://localhost:3000 (preview)
```

### Features

- **Hot Module Replacement (HMR)**: Changes auto-reload in browser
- **Source maps**: Full debugging support
- **Type checking**: Real-time TypeScript errors

### Environment Variables

Create a `.env.local` file (not committed to git):

```bash
GEMINI_API_KEY=your-api-key-here
APP_URL=http://localhost:5173
```

---

## Docker Deployment

### Build Production Image

```bash
# Build the multi-stage Docker image
docker build -t crossplane-demo:latest .

# Run the container
docker run -p 3000:3000 \
  -e GEMINI_API_KEY=your-api-key \
  crossplane-demo:latest

# Access at http://localhost:3000
```

### Build Development Image (with hot reload)

```bash
# Build dev image
docker build -f Dockerfile.dev -t crossplane-demo:dev .

# Run with volume mounts for hot reload
docker run -p 5173:5173 -p 3000:3000 \
  -v $(pwd)/src:/app/src \
  -v $(pwd)/README.md:/app/README.md \
  crossplane-demo:dev

# Access at http://localhost:5173
```

### Docker Compose

#### Production Stack

```bash
# Start production container
docker-compose up

# Access at http://localhost:3000
```

#### Development Stack (with hot reload)

```bash
# Start with development profile
docker-compose --profile dev up

# Access dev server at http://localhost:5173
```

#### Stop Services

```bash
docker-compose down
```

---

## Production Deployment

### Cloud Run (Google Cloud)

```bash
# 1. Build and push to Google Container Registry
docker build -t gcr.io/PROJECT_ID/crossplane-demo:latest .
docker push gcr.io/PROJECT_ID/crossplane-demo:latest

# 2. Deploy to Cloud Run
gcloud run deploy crossplane-demo \
  --image gcr.io/PROJECT_ID/crossplane-demo:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=your-api-key,APP_URL=https://your-cloud-run-url

# 3. Get the service URL
gcloud run services describe crossplane-demo --platform managed --region us-central1
```

### Kubernetes Deployment

```bash
# Create a namespace
kubectl create namespace crossplane-demo

# Create a secret for API keys
kubectl create secret generic app-secrets \
  --from-literal=GEMINI_API_KEY=your-api-key \
  -n crossplane-demo

# Create deployment manifest
cat > k8s-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crossplane-demo
  namespace: crossplane-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: crossplane-demo
  template:
    metadata:
      labels:
        app: crossplane-demo
    spec:
      containers:
      - name: frontend
        image: ghcr.io/yourusername/crossplane-demo:latest
        ports:
        - containerPort: 3000
        env:
        - name: GEMINI_API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: GEMINI_API_KEY
        - name: APP_URL
          value: https://crossplane-demo.yourdomain.com
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: crossplane-demo-service
  namespace: crossplane-demo
spec:
  selector:
    app: crossplane-demo
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: crossplane-demo-ingress
  namespace: crossplane-demo
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - crossplane-demo.yourdomain.com
    secretName: crossplane-demo-tls
  rules:
  - host: crossplane-demo.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: crossplane-demo-service
            port:
              number: 80
EOF

# Apply the deployment
kubectl apply -f k8s-deployment.yaml

# Monitor deployment
kubectl get pods -n crossplane-demo
kubectl logs -n crossplane-demo -f deployment/crossplane-demo
```

### AWS ECS (Elastic Container Service)

```bash
# 1. Push to Amazon ECR
aws ecr create-repository --repository-name crossplane-demo --region us-east-1
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
docker tag crossplane-demo:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/crossplane-demo:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/crossplane-demo:latest

# 2. Create ECS Task Definition
aws ecs register-task-definition \
  --family crossplane-demo \
  --network-mode awsvpc \
  --requires-compatibilities FARGATE \
  --cpu 512 \
  --memory 1024 \
  --container-definitions '[
    {
      "name": "crossplane-demo",
      "image": "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/crossplane-demo:latest",
      "portMappings": [{
        "containerPort": 3000,
        "hostPort": 3000,
        "protocol": "tcp"
      }],
      "environment": [
        {
          "name": "GEMINI_API_KEY",
          "value": "your-api-key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/crossplane-demo",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]'

# 3. Create or update ECS Service (requires existing ECS cluster)
aws ecs create-service \
  --cluster crossplane-demo-cluster \
  --service-name crossplane-demo \
  --task-definition crossplane-demo:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}
```

---

## GitHub Actions CI/CD

The project includes a comprehensive GitHub Actions workflow (`.github/workflows/ci-cd.yml`) that:

1. **Lints & Tests**: Runs TypeScript checks and builds
2. **Validates Infrastructure**: Validates Terraform and Kubernetes manifests
3. **Security Scanning**: Scans for vulnerabilities and exposed secrets
4. **Builds & Pushes**: Builds Docker image and pushes to GitHub Container Registry on main branch

### Triggering Workflows

Workflows automatically run on:

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

### Setting Up Container Registry

```bash
# GitHub Container Registry (GHCR) is automatically available
# Just ensure your GitHub Actions workflow has package write permissions

# To push to GHCR manually:
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker tag crossplane-demo:latest ghcr.io/USERNAME/crossplane-demo:latest
docker push ghcr.io/USERNAME/crossplane-demo:latest
```

### Manual Workflow Trigger

```bash
# Trigger workflow via GitHub CLI
gh workflow run ci-cd.yml -r main
```

### Workflow Status Badge

Add to README.md:

```markdown
[![CI/CD Pipeline](https://github.com/USERNAME/Crossplane-AWS-Demo/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/USERNAME/Crossplane-AWS-Demo/actions)
```

---

## Troubleshooting

### Docker Build Fails

**Problem**: `ERROR: failed to solve with frontend dockerfile.v0`

**Solution**:
```bash
# Clear Docker cache and rebuild
docker system prune -a
docker build --no-cache -t crossplane-demo:latest .
```

### Port Already in Use

**Problem**: `Address already in use`

**Solution**:
```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>

# Or use different port
docker run -p 3001:3000 crossplane-demo:latest
```

### Environment Variables Not Loading

**Problem**: API key not available in container

**Solution**:
```bash
# Verify environment variable is set
docker run --env-file .env -p 3000:3000 crossplane-demo:latest

# Or pass directly
docker run -e GEMINI_API_KEY=your-key -p 3000:3000 crossplane-demo:latest

# Verify it's set inside container
docker run -it crossplane-demo:latest env | grep GEMINI
```

### Hot Reload Not Working in Development

**Problem**: Changes don't reload in browser

**Solution**:
```bash
# Ensure you're using dev container/docker-compose
docker-compose --profile dev up

# Check Vite is running on correct port
# Should be http://localhost:5173 (not 3000)

# Verify volume mounts are working
docker inspect <container_id> | grep -A 5 Mounts
```

### Container Exits Immediately

**Problem**: Docker container stops right after starting

**Solution**:
```bash
# Check logs
docker run crossplane-demo:latest  # Run without -d to see output

# Or check logs of exited container
docker logs <container_id>

# Common cause: Missing environment variables
# Make sure GEMINI_API_KEY is set
```

### Health Check Failing

**Problem**: Container marked as unhealthy

**Solution**:
```bash
# Check if port 3000 is responding
docker run --name test-container crossplane-demo:latest
docker exec test-container wget -q -O- http://localhost:3000 || echo "Failed"

# May need to wait longer for startup
docker run --health-start-period=30s crossplane-demo:latest
```

---

## Performance Tips

### Optimize Docker Image Size

```bash
# Check current image size
docker images | grep crossplane-demo

# Multi-stage build reduces size by ~70% (builder + runtime stages)
# Current size should be ~150MB (vs ~800MB with all node_modules)
```

### Optimize Build Time

```bash
# Use Docker BuildKit for faster builds
DOCKER_BUILDKIT=1 docker build .

# Enable caching in GitHub Actions
# The ci-cd.yml workflow already includes Docker cache configuration
```

### Resource Limits

Set appropriate limits for production:

```bash
# In docker-compose.yml or Kubernetes manifests
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

---

## Security Best Practices

1. **Never commit secrets**: Use `.env` files and GitHub Secrets
2. **Use non-root user**: Dockerfile runs as `appuser` (UID 1001)
3. **Scan for vulnerabilities**: GitHub Actions includes Trivy scanning
4. **Keep dependencies updated**: Run `npm update` regularly
5. **Use HTTPS in production**: Enable TLS/SSL termination

---

## Monitoring & Logging

### Docker Logs

```bash
# View logs
docker logs <container_id>

# Stream logs (follow)
docker logs -f <container_id>

# Last 100 lines with timestamps
docker logs --tail 100 -t <container_id>
```

### Kubernetes Logs

```bash
# View pod logs
kubectl logs -n crossplane-demo deployment/crossplane-demo

# Stream logs
kubectl logs -n crossplane-demo -f deployment/crossplane-demo

# View previous logs (if pod restarted)
kubectl logs -n crossplane-demo --previous deployment/crossplane-demo
```

---

## Next Steps

1. Set up GitHub Secrets for automated deployments
2. Configure a domain and SSL certificate
3. Set up monitoring/logging (CloudWatch, DataDog, etc.)
4. Implement auto-scaling policies
5. Set up backup and disaster recovery procedures

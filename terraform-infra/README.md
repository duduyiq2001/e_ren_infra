# Terraform Infrastructure Management

This directory manages **AWS infrastructure** for E-Ren (VPC, EKS, RDS, S3, etc.).

## Purpose

Separate workspace for infrastructure to avoid checking IAM user resources during deployments.

## Workspace

- **Terraform Cloud Workspace:** `eren-prod`
- **State:** Managed separately from IAM
- **Focus:** Infrastructure only (VPC, EKS, RDS, EC2, S3, etc.)

## Quick Start

### First Time Setup

```bash
cd terraform-infra
terraform login   # If not already logged in
terraform init
```

### Deploying Infrastructure

```bash
terraform plan    # Preview changes
terraform apply   # Deploy infrastructure
```

## What Goes Here

**Infrastructure resources:**
- VPC, subnets, security groups
- EKS clusters and node groups
- RDS databases
- S3 buckets (application data)
- Load balancers
- Route53 DNS
- CloudWatch monitoring
- Secrets Manager

**NOT here:**
- IAM users (see `terraform-iam/`)
- IAM groups (see `terraform-iam/`)
- IAM user policies (see `terraform-iam/`)

## Current Files

```
terraform-infra/
├── backend.tf                   # Terraform Cloud config (workspace: eren-prod)
├── provider.tf                  # AWS provider
├── variables.tf                 # Input variables
├── terraform.tfvars.example     # Example variable values
├── eks.tf                       # EKS cluster with VPC and Karpenter
├── karpenter-config.yaml        # Karpenter NodePool configs (apply after cluster)
└── README.md                    # This file
```

## Deployed Infrastructure

### EKS Cluster (eks.tf)

**Architecture:**

Three node groups:

1. **Karpenter controller** (1x t4g.nano ARM) - ~$3/month
   - Runs Karpenter autoscaler only
   - Tainted to prevent other pods from scheduling here
   - Always running (lightweight)

2. **Rails application** (1x t4g.medium ARM) - ~$15/month
   - Runs Rails app (no cold starts)
   - Runs core services (ingress, monitoring)
   - Always running (critical workload)

3. **Spot nodes** (0-2x t4g.small/medium ARM) - Karpenter-managed
   - Auto-provisions for traffic bursts
   - Scales to 0 when idle ($0)
   - 70% cheaper than on-demand

**Total baseline cost**: ~$18/month + NAT gateway (~$32/month) = **~$50/month**

**What's included:**
- VPC with public and private subnets across 2 AZs
- EKS cluster (Kubernetes 1.29)
- 2 fixed node groups (Karpenter + Rails)
- Karpenter autoscaler with spot instance support
- EBS CSI driver for persistent volumes
- Pod Identity Agent for IRSA

**Cost optimizations:**
- Single NAT gateway (~$32/month vs $64 for 2)
- ARM instances (~20% cheaper than x86)
- Tiny dedicated Karpenter node (t4g.nano)
- Spot instances scale to 0 when idle ($0 when not in use)

**Deployed:**

```bash
terraform plan
terraform apply
```

### Configure kubectl

After cluster is created:

```bash
aws eks update-kubeconfig --region us-east-1 --name e-ren-cluster
kubectl get nodes
```

### Deploy Karpenter NodePools

Apply Karpenter configuration to enable autoscaling:

```bash
kubectl apply -f karpenter-config.yaml
```

This creates:
- **EC2NodeClass**: Infrastructure config for Karpenter-provisioned nodes
- **Spot NodePool**: For burst traffic (max 2 nodes, spot instances)

**Verify Karpenter:**

```bash
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter
```

### Deploying Workloads

#### Rails Application (Fixed On-Demand Node)

Main application runs on the dedicated t4g.medium node:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails-app
spec:
  replicas: 1  # Single replica on fixed node
  template:
    spec:
      nodeSelector:
        workload-type: critical  # Targets t4g.medium node
      containers:
        - name: app
          image: your-registry/rails-app:latest
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
```

#### Burst Traffic (Spot Nodes)

Additional Rails replicas for traffic bursts - Karpenter auto-provisions spot nodes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails-app-burst
spec:
  replicas: 0  # HPA will scale this up/down
  template:
    spec:
      nodeSelector:
        workload-type: batch  # Targets Karpenter-managed spot nodes
      tolerations:
        - key: spot
          operator: Equal
          value: "true"
          effect: NO_SCHEDULE
      containers:
        - name: app
          image: your-registry/rails-app:latest
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: rails-app-burst
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rails-app-burst
  minReplicas: 0
  maxReplicas: 4  # Will trigger Karpenter to provision up to 2 spot nodes
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**How it works:**
1. Fixed node always runs 1 Rails replica (handles baseline traffic)
2. When traffic increases, HPA scales up `rails-app-burst`
3. Karpenter sees pending pods, provisions spot nodes (0-2 nodes)
4. When traffic drops, HPA scales down, Karpenter terminates idle spot nodes

**Note:** Spot instances can be interrupted with 2 minutes notice. Rails can handle this since:
- At least 1 replica always runs on the fixed node
- Multiple replicas distribute load
- Load balancer automatically routes around interrupted pods

### Exposing Services with ALB

The AWS Load Balancer Controller is automatically installed. Create an Ingress to expose your Rails app:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: rails-app
spec:
  type: NodePort  # ALB targets NodePort services
  selector:
    app: rails-app
  ports:
    - port: 80
      targetPort: 3000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rails-app
  annotations:
    # Creates an internet-facing ALB
    alb.ingress.kubernetes.io/scheme: internet-facing
    # Target type: ip mode (more efficient than instance mode)
    alb.ingress.kubernetes.io/target-type: ip
    # Health check path
    alb.ingress.kubernetes.io/healthcheck-path: /health
    # Listen on HTTP (add HTTPS later with ACM certificate)
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: rails-app
                port:
                  number: 80
```

**After applying:**
```bash
kubectl apply -f rails-ingress.yaml

# Wait for ALB to be provisioned (~2-3 minutes)
kubectl get ingress rails-app

# Get the ALB URL
kubectl get ingress rails-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# Output: k8s-default-railsapp-abc123.us-east-1.elb.amazonaws.com
```

**For HTTPS** (add later with Route53 + ACM):
```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
```

## Variables

See `variables.tf` for all available variables.

**Key variables:**
- `aws_region` - AWS region (default: us-east-1)
- `environment` - Environment name (default: prod)

Customize via `terraform.tfvars`:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Note:** `terraform.tfvars` is gitignored

## Workflow

### CLI-Driven (Current)

```bash
# Make changes to .tf files
vim vpc.tf

# Preview
terraform plan

# Apply
terraform apply
```

### State Management

- State stored in Terraform Cloud (encrypted)
- Automatic locking during operations
- Version history and rollback
- Team collaboration built-in

## Benefits of Separate Workspaces

✅ **Fast deploys** - Doesn't check 50+ IAM users when deploying infrastructure

✅ **Clean plan output** - Only shows infrastructure changes

✅ **Independent apply** - Can deploy infrastructure without touching IAM

✅ **Separation of concerns** - Infrastructure and access management are separate

## Troubleshooting

### Error: "Workspace not found"

The workspace should already exist (`eren-prod`). If not:
1. Go to https://app.terraform.io
2. Organization: `eren-team`
3. Create workspace: `eren-prod`
4. Workflow: CLI-Driven

### Error: "No valid credential sources"

AWS credentials should already be in Terraform Cloud workspace. If not:
1. Workspace Settings → Variables
2. Add environment variables:
   - `AWS_ACCESS_KEY_ID` = (from bootstrap script)
   - `AWS_SECRET_ACCESS_KEY` = (sensitive)
   - `AWS_REGION` = us-east-1

### Error: "Reference to undeclared resource"

Make sure you're in the right directory:
- IAM resources → `cd terraform-iam`
- Infrastructure → `cd terraform-infra`

## Security Best Practices

- Review `terraform plan` before applying
- Never hardcode secrets in .tf files
- Use AWS Secrets Manager for application secrets
- Enable encryption at rest for all data stores
- Use VPC for network isolation
- Follow principle of least privilege

## Next Steps

1. Define VPC and networking (`vpc.tf`)
2. Create EKS cluster (`eks.tf`)
3. Set up RDS database (`rds.tf`)
4. Configure S3 buckets (`s3.tf`)
5. Add monitoring and logging

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

**What's included:**
- VPC with public and private subnets across 2 AZs
- EKS cluster (Kubernetes 1.29)
- Karpenter controller node group (2-3 t4g.small ARM nodes)
- Karpenter autoscaler for intelligent scaling
- EBS CSI driver for persistent volumes
- Pod Identity Agent for IRSA

**Cost optimizations:**
- Single NAT gateway (~$32/month vs $96 for 3)
- ARM instances (~20% cheaper than x86)
- Karpenter manages spot instances (up to 70% cheaper)
- Small controller nodes (t4g.small)

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
- **On-demand NodePool**: For critical workloads (max 16 CPU, 32Gi RAM)
- **Spot NodePool**: For batch jobs (max 64 CPU, 128Gi RAM, spot instances)

**Verify Karpenter:**

```bash
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter
```

### Deploying Workloads

#### Critical Workloads (On-Demand)

For databases, stateful apps, and critical services:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails-app
spec:
  template:
    spec:
      nodeSelector:
        workload-type: critical  # Schedule on on-demand nodes
      containers:
        - name: app
          image: rails-app:latest
```

#### Batch Workloads (Spot)

For background jobs, batch processing, and fault-tolerant services:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
spec:
  template:
    spec:
      nodeSelector:
        workload-type: batch  # Schedule on spot nodes
      tolerations:
        - key: spot
          operator: Equal
          value: "true"
          effect: NoSchedule
      containers:
        - name: processor
          image: data-processor:latest
```

**Note:** Spot instances can be interrupted with 2 minutes notice. Use for:
- Batch jobs
- Stateless web servers (with multiple replicas)
- CI/CD workers
- Background tasks

**Avoid spot for:**
- Databases
- Stateful applications
- Single-replica critical services

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

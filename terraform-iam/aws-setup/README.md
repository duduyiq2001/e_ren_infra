# AWS Setup for Terraform

## Overview

This directory contains a **one-time bootstrap script** to create the initial Terraform IAM user. After bootstrapping, **all other IAM resources** (users, roles, policies) should be managed via Terraform itself.

## The Bootstrap Pattern

```
┌─────────────────────────────────────────────────────────┐
│  Step 1: Run bootstrap script (ONCE)                   │
│  → Creates terraform-provisioner IAM user              │
│  → Generates access keys                               │
│  → Gives Terraform permission to manage AWS            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Step 2: Store credentials in Terraform Cloud          │
│  → Environment variables (encrypted)                   │
│  → AWS_ACCESS_KEY_ID                                   │
│  → AWS_SECRET_ACCESS_KEY                               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Step 3: Use Terraform for everything else             │
│  → Create IAM users for teammates                      │
│  → Create IAM roles (dev, ops, readonly)               │
│  → Manage policies via terraform/*.tf files            │
│  → Version controlled + reviewable in PRs              │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- AWS CLI installed and configured
- AWS account with admin permissions (for initial bootstrap)
- Terraform Cloud account (free tier is fine)

### Step 1: Bootstrap Terraform User

```bash
cd terraform/aws-setup
./bootstrap-terraform-user.sh
```

**What this script does:**
1. Creates IAM policy: `TerraformProvisionerPolicy`
2. Creates IAM user: `terraform-provisioner`
3. Attaches policy to user
4. Generates access key pair
5. Saves credentials to `terraform-credentials.txt`

**Output:**
```
╔════════════════════════════════════════════════════════════╗
║               ✓ Bootstrap Complete!                       ║
╚════════════════════════════════════════════════════════════╝

AWS Credentials Created:
  IAM User:          terraform-provisioner
  Access Key ID:     AKIAIOSFODNN7EXAMPLE
  Secret Access Key: wJalrXUtn...EXAMPLE

📄 Credentials saved to: terraform-credentials.txt
```

### Step 2: Set Up Terraform Cloud

1. **Sign up:** https://app.terraform.io/signup
2. **Create organization:** `eren-team`
3. **Create workspace:** `eren-prod`
4. **Add environment variables:**
   - Go to: Workspace Settings → Variables
   - Add these as **ENVIRONMENT** variables (mark as **SENSITIVE**):
     ```
     AWS_ACCESS_KEY_ID     = AKIAIOSFODNN7EXAMPLE
     AWS_SECRET_ACCESS_KEY = (paste from terraform-credentials.txt)
     AWS_REGION            = us-east-1
     ```

### Step 3: Configure Terraform Backend

```bash
cd ../  # Go to terraform/ directory
terraform login  # Opens browser to get token
terraform init   # Initializes Terraform Cloud backend
```

### Step 4: Clean Up

```bash
# IMPORTANT: Delete credentials file after storing in Terraform Cloud
rm aws-setup/terraform-credentials.txt
```

## What Gets Created

### IAM Policy: `TerraformProvisionerPolicy`

Grants permissions for:
- **VPC:** Create/manage VPCs, subnets, security groups, route tables
- **EKS:** Create/manage Kubernetes clusters and node groups
- **RDS:** Create/manage databases and subnet groups
- **S3:** Create/manage buckets and objects
- **IAM:** Create/manage roles and policies (for AWS services, not users)
- **Route53:** Manage DNS zones and records
- **CloudWatch:** Manage logs and metrics
- **ELB:** Manage load balancers
- **KMS:** Manage encryption keys
- **Secrets Manager:** Manage secrets
- **ACM:** Manage SSL certificates

**Policy file:** `policies/terraform-provisioner.json`

### IAM User: `terraform-provisioner`

- Programmatic access only (access key + secret)
- No AWS Console access
- Used exclusively by Terraform Cloud
- Credentials stored encrypted in Terraform Cloud

## Managing Team Members (Via Terraform)

**DON'T** run the bootstrap script again for new teammates!

**DO** create Terraform resources instead:

```hcl
# terraform/iam-users.tf

# Example: Developer user
resource "aws_iam_user" "alice" {
  name = "alice@company.com"

  tags = {
    Team = "Engineering"
    Role = "Developer"
  }
}

resource "aws_iam_user_login_profile" "alice" {
  user = aws_iam_user.alice.name
  password_reset_required = true
}

resource "aws_iam_user_policy_attachment" "alice_developer" {
  user       = aws_iam_user.alice.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

# Example: Developer policy
resource "aws_iam_policy" "developer_policy" {
  name        = "DeveloperPolicy"
  description = "Policy for developers - read-only prod, full dev/staging access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyProd"
        Effect = "Allow"
        Action = [
          "eks:Describe*",
          "rds:Describe*",
          "s3:Get*",
          "s3:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "FullDevAccess"
        Effect = "Allow"
        Action = "*"
        Resource = [
          "arn:aws:eks:*:*:cluster/dev-*",
          "arn:aws:rds:*:*:db:dev-*",
          "arn:aws:s3:::dev-*"
        ]
      }
    ]
  })
}
```

**To add a new teammate:**
```bash
# 1. Add resource block to terraform/iam-users.tf
# 2. Run terraform plan to review changes
# 3. Run terraform apply to create user
# 4. Send credentials via secure channel
```

## Directory Structure

```
aws-setup/
├── policies/
│   └── terraform-provisioner.json    # IAM policy for Terraform
├── bootstrap-terraform-user.sh       # One-time setup script
├── README.md                          # This file
└── terraform-credentials.txt         # Generated by script (DELETE after use!)
```

## Security Best Practices

### ✅ DO

- Run bootstrap script **once** per AWS account
- Store credentials **only** in Terraform Cloud
- Use Terraform to manage all other IAM resources
- Enable MFA for IAM users with console access
- Rotate access keys every 90 days
- Use separate AWS accounts for dev/staging/prod (future)
- Review Terraform plans before applying

### ❌ DON'T

- Commit `terraform-credentials.txt` to Git (already in .gitignore)
- Share access keys via email/Slack
- Create IAM users manually in AWS Console (use Terraform!)
- Give everyone admin permissions (use least-privilege policies)
- Reuse access keys across environments

## Troubleshooting

### Error: "AccessDenied" when running bootstrap script

**Cause:** Your current AWS CLI user doesn't have IAM permissions.

**Fix:** Configure AWS CLI with admin credentials:
```bash
aws configure
# Enter access key ID and secret for an admin user
```

### Error: "Policy already exists"

**Cause:** You've run the bootstrap script before.

**Fix:** Script will automatically use existing policy. To start fresh:
```bash
aws iam delete-user-policy-attachment \
  --user-name terraform-provisioner \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/TerraformProvisionerPolicy

aws iam delete-access-key \
  --user-name terraform-provisioner \
  --access-key-id YOUR_ACCESS_KEY_ID

aws iam delete-user --user-name terraform-provisioner
aws iam delete-policy --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/TerraformProvisionerPolicy

# Then re-run bootstrap script
./bootstrap-terraform-user.sh
```

### Error: "User already has access key"

**Cause:** Access key already created for this user.

**Fix:** Either:
1. Use existing key (should be in `terraform-credentials.txt`)
2. Delete old key and create new one:
   ```bash
   aws iam delete-access-key \
     --user-name terraform-provisioner \
     --access-key-id YOUR_OLD_KEY_ID

   ./bootstrap-terraform-user.sh
   ```

## Next Steps

After bootstrapping:

1. ✅ Configure Terraform backend (see `../backend.tf`)
2. ✅ Define infrastructure in Terraform files
3. ✅ Create IAM policies for team roles (dev, ops, readonly)
4. ✅ Create IAM users for teammates via Terraform
5. ✅ Set up EKS cluster, RDS, VPC via Terraform
6. ✅ Review and apply changes via `terraform plan` and `terraform apply`

## References

- [Terraform Cloud Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

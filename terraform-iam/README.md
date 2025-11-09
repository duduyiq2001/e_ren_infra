# Terraform IAM Management

This directory manages **IAM users, groups, and policies** for the E-Ren team.

## Purpose

Separate workspace for IAM to avoid checking user resources during infrastructure deployments.

## Workspace

- **Terraform Cloud Workspace:** `eren-iam`
- **State:** Managed separately from infrastructure

## Quick Start

### First Time Setup

```bash
cd terraform-iam
terraform login
terraform init
```

### Adding a New Team Member

1. **Edit `iam-users.tf`**

Uncomment and customize an example:

```hcl
resource "aws_iam_user" "alice" {
  name = "alice@yourcompany.com"

  tags = {
    Name  = "Alice Developer"
    Team  = "Engineering"
    Email = "alice@yourcompany.com"
  }
}

resource "aws_iam_user_login_profile" "alice" {
  user                    = aws_iam_user.alice.name
  password_reset_required = true
}

resource "aws_iam_user_group_membership" "alice" {
  user   = aws_iam_user.alice.name
  groups = [aws_iam_group.developers.name]
}
```

2. **Apply changes**

```bash
terraform plan   # Review what will be created
terraform apply  # Create the user
```

3. **Get initial password**

```bash
terraform output -raw alice_initial_password
```

4. **Share with user securely** (via 1Password/LastPass)

5. **User logs in**
   - URL: `https://YOUR_ACCOUNT_ID.signin.aws.amazon.com/console`
   - Username: `alice@yourcompany.com`
   - Password: (from terraform output)
   - Must change password on first login

## What's Included

### Policies

- **DeveloperReadOnlyPolicy** - View all resources, can't create/delete
- **DevOpsReadOnlyPolicy** - Same as developer for now
- **ConsoleAccessPolicy** - Manage own passwords and MFA

### Groups

- **Developers** - Attached to DeveloperReadOnlyPolicy
- **DevOps** - Attached to DevOpsReadOnlyPolicy

### Permissions

✅ **CAN DO:**
- View all AWS resources (EC2, EKS, RDS, S3, VPC, etc.)
- Read CloudWatch logs and metrics
- Read all secrets (including prod)
- Access Kubernetes API (kubectl)
- View IAM users/roles/policies

❌ **CANNOT DO:**
- Create any resources
- Delete any resources
- Modify infrastructure
- Change IAM permissions

## Files

```
terraform-iam/
├── backend.tf          # Terraform Cloud config (workspace: eren-iam)
├── provider.tf         # AWS provider
├── iam-policies.tf     # Read-only policies
├── iam-groups.tf       # Developer and DevOps groups
├── iam-users.tf        # Team members (gitignored)
└── README.md           # This file
```

## Security Notes

- `iam-users.tf` is gitignored (team privacy)
- Initial passwords in Terraform state (marked sensitive)
- Users must change password on first login
- All infrastructure changes via Terraform only
- No create/delete permissions for team members

## Troubleshooting

### Error: "Workspace not found"

Create the workspace in Terraform Cloud:
1. Go to https://app.terraform.io
2. Organization: `eren-team`
3. Create workspace: `eren-iam`
4. Workflow: CLI-Driven

### Error: "No valid credential sources"

Add AWS credentials to Terraform Cloud workspace:
1. Workspace Settings → Variables
2. Add environment variables:
   - `AWS_ACCESS_KEY_ID` = (from bootstrap script)
   - `AWS_SECRET_ACCESS_KEY` = (sensitive)
   - `AWS_REGION` = us-east-1

## Best Practices

- Review `terraform plan` before applying
- Add users via Terraform, not AWS Console
- Rotate access keys every 90 days
- Enable MFA for all users (optional but recommended)
- Keep `iam-users.tf` out of Git (already configured)

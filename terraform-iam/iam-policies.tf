# IAM Policies for Team Members
#
# These policies provide read-only access with explicit denies on destructive actions.
# Developers can see all resources but cannot create or destroy infrastructure.

# ═══════════════════════════════════════════════════════════
#   Developer Policy - Read-Only + Limited Actions
# ═══════════════════════════════════════════════════════════

resource "aws_iam_policy" "developer_policy" {
  name        = "DeveloperReadOnlyPolicy"
  description = "Read-only access to AWS resources with explicit denies on destructive actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          # EC2 - Describe only
          "ec2:Describe*",
          "ec2:Get*",
          "ec2:List*",

          # EKS - Describe only
          "eks:Describe*",
          "eks:List*",
          "eks:AccessKubernetesApi",

          # RDS - Describe only
          "rds:Describe*",
          "rds:List*",

          # S3 - Read only
          "s3:Get*",
          "s3:List*",

          # IAM - Read only (see what exists)
          "iam:Get*",
          "iam:List*",

          # CloudWatch - Read logs and metrics
          "logs:Describe*",
          "logs:Get*",
          "logs:List*",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",

          # VPC - Describe only
          "vpc:Describe*",
          "vpc:Get*",
          "vpc:List*",

          # Load Balancers - Describe only
          "elasticloadbalancing:Describe*",

          # Route53 - Read only
          "route53:Get*",
          "route53:List*",

          # Secrets Manager - Read all secrets (small team, devs can see prod)
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",

          # KMS - Decrypt (for reading encrypted resources)
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:List*",

          # CloudFormation - Read only
          "cloudformation:Describe*",
          "cloudformation:Get*",
          "cloudformation:List*",

          # Auto Scaling - Read only
          "autoscaling:Describe*",

          # Lambda - Read only
          "lambda:Get*",
          "lambda:List*",

          # SNS/SQS - Read only
          "sns:Get*",
          "sns:List*",
          "sqs:Get*",
          "sqs:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowKubectlAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllCreation"
        Effect = "Deny"
        Action = [
          "ec2:Create*",
          "ec2:Run*",
          "eks:Create*",
          "rds:Create*",
          "s3:CreateBucket",
          "iam:Create*",
          "vpc:Create*",
          "elasticloadbalancing:Create*",
          "route53:Create*",
          "cloudformation:Create*",
          "lambda:Create*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllDeletion"
        Effect = "Deny"
        Action = [
          "ec2:Delete*",
          "ec2:Terminate*",
          "eks:Delete*",
          "rds:Delete*",
          "s3:DeleteBucket",
          "s3:DeleteObject",
          "iam:Delete*",
          "vpc:Delete*",
          "elasticloadbalancing:Delete*",
          "route53:Delete*",
          "cloudformation:Delete*",
          "lambda:Delete*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllModification"
        Effect = "Deny"
        Action = [
          "ec2:Modify*",
          "ec2:Update*",
          "eks:Update*",
          "rds:Modify*",
          "iam:Update*",
          "iam:Put*",
          "iam:Attach*",
          "iam:Detach*",
          "vpc:Modify*",
          "elasticloadbalancing:Modify*",
          "route53:Change*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyIAMChanges"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutUserPolicy",
          "iam:PutRolePolicy"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "DeveloperReadOnlyPolicy"
    Description = "Read-only access for developers"
  }
}

# ═══════════════════════════════════════════════════════════
#   DevOps Policy - Same as Developer for now
# ═══════════════════════════════════════════════════════════
#
# Note: DevOps users get the same read-only access.
# If you need to give them more permissions later, create a separate policy.
# For now, infrastructure changes should ONLY happen via Terraform.

resource "aws_iam_policy" "devops_policy" {
  name        = "DevOpsReadOnlyPolicy"
  description = "Read-only access for DevOps team (use Terraform for changes)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "eks:Describe*",
          "eks:List*",
          "eks:AccessKubernetesApi",
          "rds:Describe*",
          "s3:Get*",
          "s3:List*",
          "iam:Get*",
          "iam:List*",
          "logs:*",
          "cloudwatch:*",
          "vpc:Describe*",
          "elasticloadbalancing:Describe*",
          "route53:Get*",
          "route53:List*",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:List*",
          "cloudformation:Describe*",
          "autoscaling:Describe*",
          "lambda:Get*",
          "lambda:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllCreation"
        Effect = "Deny"
        Action = [
          "ec2:Create*",
          "ec2:Run*",
          "eks:Create*",
          "rds:Create*",
          "s3:CreateBucket",
          "iam:Create*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllDeletion"
        Effect = "Deny"
        Action = [
          "ec2:Delete*",
          "ec2:Terminate*",
          "eks:Delete*",
          "rds:Delete*",
          "s3:DeleteBucket",
          "iam:Delete*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyIAMChanges"
        Effect = "Deny"
        Action = [
          "iam:*User*",
          "iam:*Role*",
          "iam:*Policy*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "DevOpsReadOnlyPolicy"
    Description = "Read-only access for DevOps team"
  }
}

# ═══════════════════════════════════════════════════════════
#   Outputs
# ═══════════════════════════════════════════════════════════

output "developer_policy_arn" {
  description = "ARN of the Developer ReadOnly policy"
  value       = aws_iam_policy.developer_policy.arn
}

output "devops_policy_arn" {
  description = "ARN of the DevOps ReadOnly policy"
  value       = aws_iam_policy.devops_policy.arn
}

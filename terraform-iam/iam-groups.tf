# IAM Groups for Team Organization
#
# Groups make it easy to manage permissions for multiple users.
# Just add users to the appropriate group instead of attaching policies individually.

# ═══════════════════════════════════════════════════════════
#   Developer Group
# ═══════════════════════════════════════════════════════════

resource "aws_iam_group" "developers" {
  name = "Developers"
  path = "/"
}

resource "aws_iam_group_policy_attachment" "developers_policy" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

# ═══════════════════════════════════════════════════════════
#   DevOps Group
# ═══════════════════════════════════════════════════════════

resource "aws_iam_group" "devops" {
  name = "DevOps"
  path = "/"
}

resource "aws_iam_group_policy_attachment" "devops_policy" {
  group      = aws_iam_group.devops.name
  policy_arn = aws_iam_policy.devops_policy.arn
}

# ═══════════════════════════════════════════════════════════
#   Console Access - Allow password login
# ═══════════════════════════════════════════════════════════

# This policy allows users to manage their own passwords and MFA
resource "aws_iam_policy" "console_access" {
  name        = "ConsoleAccessPolicy"
  description = "Allow users to manage their own passwords and MFA devices"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowViewAccountInfo"
        Effect = "Allow"
        Action = [
          "iam:GetAccountPasswordPolicy",
          "iam:GetAccountSummary",
          "iam:ListVirtualMFADevices"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnPasswords"
        Effect = "Allow"
        Action = [
          "iam:ChangePassword",
          "iam:GetUser"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}"
      },
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/$${aws:username}",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}"
        ]
      },
      {
        Sid    = "AllowDeactivateOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:DeactivateMFADevice"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:mfa/$${aws:username}",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/$${aws:username}"
        ]
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })
}

# Attach console access to both groups
resource "aws_iam_group_policy_attachment" "developers_console" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.console_access.arn
}

resource "aws_iam_group_policy_attachment" "devops_console" {
  group      = aws_iam_group.devops.name
  policy_arn = aws_iam_policy.console_access.arn
}

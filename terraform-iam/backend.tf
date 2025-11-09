# Terraform Cloud Backend Configuration - IAM Management
#
# This workspace manages IAM users, groups, and policies.
# Separate from infrastructure to avoid checking user resources during infra deploys.

terraform {
  # Require Terraform 1.6 or higher
  required_version = ">= 1.6.0"

  # Terraform Cloud backend
  cloud {
    organization = "eren-team"

    workspaces {
      name = "eren-iam"  # Separate workspace for IAM resources
    }
  }

  # Required providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

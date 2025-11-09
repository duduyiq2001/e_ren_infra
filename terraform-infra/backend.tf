# Terraform Cloud Backend Configuration
#
# This configures Terraform to use Terraform Cloud for state management.
# Benefits:
# - Encrypted state storage
# - State locking (prevents concurrent modifications)
# - Team collaboration (shared workspaces)
# - Version history and rollback
# - Free for up to 5 users
#
# Setup:
# 1. Sign up: https://app.terraform.io/signup
# 2. Create organization: "eren-team"
# 3. Create workspace: "eren-prod"
# 4. Run: terraform login
# 5. Run: terraform init

terraform {
  # Require Terraform 1.6 or higher
  required_version = ">= 1.6.0"

  # Terraform Cloud backend
  cloud {
    organization = "eren-team"

    workspaces {
      name = "eren-prod"
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

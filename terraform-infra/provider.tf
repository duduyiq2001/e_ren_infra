# AWS Provider Configuration
#
# AWS credentials are provided via Terraform Cloud ENVIRONMENT variables:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - AWS_REGION (environment variable for AWS provider)
#
# Region is configured via Terraform VARIABLE (not environment variable):
# - aws_region (lowercase with underscore - matches variables.tf)
#
# These are set in Terraform Cloud workspace settings (encrypted/sensitive).

provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  default_tags {
    tags = {
      Project     = "E-Ren"
      Environment = var.environment["prod"]
      ManagedBy   = "Terraform"
      Repository  = "e_ren_infra"
      Team        = "Engineering"
    }
  }
}

# Data source to get current AWS account information
data "aws_caller_identity" "current" {}

# Filter out local zones (not supported with managed node groups)
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# AWS Provider Configuration
#
# AWS credentials are provided via Terraform Cloud environment variables:
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - AWS_REGION
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

# Data source to get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

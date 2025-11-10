# Terraform Variables

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = map(string)
  default     = {
    prod = "prod",
    dev = "dev"

                }
}

# Accept AWS_REGION from Terraform Cloud workspace (not used in code)
# This prevents "undeclared variable" errors when TF Cloud passes it
# The actual region is configured via aws_region (lowercase) above
variable "AWS_REGION" {
  description = "AWS region (passed from Terraform Cloud, unused)"
  type        = string
  default     = "us-east-1"
}

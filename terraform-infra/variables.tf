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

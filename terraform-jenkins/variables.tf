variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "jenkins-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the Jenkins VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "jenkins_admin_password" {
  description = "Admin password for Jenkins"
  type        = string
  sensitive   = true
}

variable "controller_instance_type" {
  description = "EC2 instance type for Jenkins controller"
  type        = string
  default     = "t4g.nano"
}

variable "agent_instance_type" {
  description = "EC2 instance type for Jenkins agent"
  type        = string
  default     = "t4g.medium"
}

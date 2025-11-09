# EKS Cluster with Karpenter Autoscaling
#
# Creates:
# - VPC with public and private subnets across 2 AZs
# - EKS cluster with Karpenter controller node group
# - Karpenter for intelligent autoscaling (on-demand + spot)
# - EBS CSI driver addon

# ═══════════════════════════════════════════════════════════
#   Providers
# ═══════════════════════════════════════════════════════════

provider "aws" {
  region = local.region
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # Requires awscli installed where Terraform runs
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# ═══════════════════════════════════════════════════════════
#   Data Sources
# ═══════════════════════════════════════════════════════════

# Filter out local zones (not supported with managed node groups)
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# ECR public auth for Karpenter Helm chart
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws
}

# ═══════════════════════════════════════════════════════════
#   Local Variables
# ═══════════════════════════════════════════════════════════

locals {
  cluster_name = "e-ren-cluster"
  region       = var.aws_region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Name        = "e-ren"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ═══════════════════════════════════════════════════════════
#   VPC Module
# ═══════════════════════════════════════════════════════════

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "e-ren-vpc"
  cidr = local.vpc_cidr

  azs = local.azs

  # Private subnets for EKS nodes (10.0.0.0/24, 10.0.1.0/24)
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]

  # Public subnets for load balancers (10.0.48.0/24, 10.0.49.0/24)
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  # Cost optimization: single NAT gateway shared by all AZs
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags for EKS load balancer discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Karpenter auto-discovery tag
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}

# ═══════════════════════════════════════════════════════════
#   EKS Cluster Module
# ═══════════════════════════════════════════════════════════

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  # Allow public access to cluster API
  cluster_endpoint_public_access = true

  # Grant cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent    = true
      before_compute = true
    }

    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # VPC Configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Control plane logging (optional, adds cost)
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  # ═══════════════════════════════════════════════════════════
  #   Karpenter Controller Node Group
  # ═══════════════════════════════════════════════════════════
  #
  # Small, stable node group that runs Karpenter itself.
  # Karpenter will provision additional nodes as needed.

  eks_managed_node_groups = {
    karpenter = {
      name = "e-ren-karpenter-controller"

      # ARM instances for cost savings
      instance_types = ["t4g.small"]
      ami_type       = "AL2_ARM_64"

      # Fixed size - Karpenter controller needs stable nodes
      min_size     = 2
      max_size     = 3
      desired_size = 2

      # Label ensures Karpenter runs on nodes it doesn't manage
      labels = {
        "karpenter.sh/controller" = "true"
        role                      = "karpenter-controller"
      }

      tags = {
        Name = "e-ren-karpenter-controller"
      }
    }
  }

  # Tag node security group for Karpenter discovery
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}

# ═══════════════════════════════════════════════════════════
#   EBS CSI Driver IRSA
# ═══════════════════════════════════════════════════════════

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.39"

  create_role  = true
  role_name    = "e-ren-ebs-csi-driver"
  provider_url = module.eks.oidc_provider

  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]

  tags = {
    Name = "e-ren-ebs-csi-driver"
  }
}

# ═══════════════════════════════════════════════════════════
#   Karpenter Module
# ═══════════════════════════════════════════════════════════

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.8"

  cluster_name = module.eks.cluster_name

  # Name matches role name used in EC2NodeClass (no prefix)
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = local.cluster_name
  create_pod_identity_association = true

  # Additional policies for Karpenter nodes
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

# ═══════════════════════════════════════════════════════════
#   Karpenter Helm Chart
# ═══════════════════════════════════════════════════════════

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.6.0"
  wait                = false

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    EOT
  ]

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

# ═══════════════════════════════════════════════════════════
#   Outputs
# ═══════════════════════════════════════════════════════════

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for EKS nodes)"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for load balancers)"
  value       = module.vpc.public_subnets
}

output "karpenter_queue_name" {
  description = "Karpenter SQS queue name for spot interruption handling"
  value       = module.karpenter.queue_name
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = module.karpenter.node_instance_profile_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
}

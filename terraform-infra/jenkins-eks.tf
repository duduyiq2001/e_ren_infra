# ═══════════════════════════════════════════════════════════
#   TEAM EXERCISE: Jenkins EKS Cluster
# ═══════════════════════════════════════════════════════════
#
# Task: Uncomment and fix this configuration to deploy Jenkins cluster
#
# TODO:
# 1. Fix all module references (jenkins_vpc, jenkins_eks, etc.)
# 2. Add AWS Load Balancer Controller for public access
# 2.5 can also install jenkins stuff through helm chart integration (do some research)
# 3. Test with: terraform plan
# 4. Deploy with: terraform apply
#
# ═══════════════════════════════════════════════════════════

# # Filter out local zones, which are not currently supported
# # with managed node groups
# data "aws_availability_zones" "available" {
#   filter {
#     name   = "opt-in-status"
#     values = ["opt-in-not-required"]
#   }
# }

# locals {
#   cluster_name = "jenkins-eks"
# }



# module "jenkins_vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "5.8.1"

#   name = "eren-vpc"

#   cidr = "10.0.0.0/16"
#   azs  = slice(data.aws_availability_zones.available.names, 0, 1)

#   private_subnets = ["10.0.1.0/24"]
#   public_subnets  = ["10.0.4.0/24"]

#   enable_nat_gateway   = true
#   single_nat_gateway   = true
#   enable_dns_hostnames = true

#   public_subnet_tags = {
#     "kubernetes.io/role/elb" = 1
#   }

#   private_subnet_tags = {
#     "kubernetes.io/role/internal-elb" = 1
#   }
# }

# module "jenkins_eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "20.8.5"

#   cluster_name    = local.cluster_name
#   cluster_version = "1.29"

#   cluster_endpoint_public_access           = true
#   enable_cluster_creator_admin_permissions = true

#   cluster_addons = {
#     aws-ebs-csi-driver = {
#       service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
#     }
#   }

#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.private_subnets

#   eks_managed_node_group_defaults = {
#     ami_type = "AL2_ARM_64"

#   }

#   eks_managed_node_groups = {
#     one = {
#       name = "node-group-1"

#       instance_types = ["t4g.small"]

#       min_size     = 1
#       max_size     = 1
#       desired_size = 1
#     }

#     two = {
#       name = "node-group-2"

#       instance_types = ["t4g.large"]

#       min_size     = 1
#       max_size     = 1
#       desired_size = 1
#     }
#   }
# }


# # https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/
# data "aws_iam_policy" "ebs_csi_policy" {
#   arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
# }

# module "irsa-ebs-csi" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
#   version = "5.39.0"

#   create_role                   = true
#   role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
#   provider_url                  = module.eks.oidc_provider
#   role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
#   oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
# }




# output "jenkins_cluster_endpoint" {
#   description = "EKS cluster endpoint"
#   value       = module.jenkins_eks.cluster_endpoint
# }

# output "jenkins_cluster_certificate_authority_data" {
#   description = "Base64 encoded certificate data for cluster"
#   value       = module.jenkins_eks.cluster_certificate_authority_data
#   sensitive   = true
# }

# output "jenkins_cluster_name" {
#   description = "EKS cluster name"
#   value       = module.jenkins_eks.cluster_name
# }

# output "jenkins_cluster_oidc_provider_arn" {
#   description = "OIDC provider ARN for IRSA"
#   value       = module.jenkins_eks.oidc_provider_arn
# }

# output "jenkins_vpc_id" {
#   description = "VPC ID"
#   value       = module.vpc.vpc_id
# }

# output "jenkins_private_subnet_ids" {
#   description = "Private subnet IDs (for EKS nodes)"
#   value       = module.vpc.private_subnets
# }

# output "jenkins_public_subnet_ids" {
#   description = "Public subnet IDs (for load balancers)"
#   value       = module.vpc.public_subnets
# }

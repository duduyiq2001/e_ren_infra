locals {
  cluster_name = var.cluster_name
  common_tags = {
    Cluster     = local.cluster_name
    Terraform   = "true"
    Environment = "prod"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b",
  ]

  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  eks_managed_node_groups = {
    jenkins_controller = {
      name = "jenkins-controller"
      instance_types = [var.controller_instance_type]
      desired_size   = 1
      min_size       = 1
      max_size       = 1

      labels = {
        role     = "controller"
        workload = "jenkins-master"
      }

      taints = [{
        key    = "jenkins.io/controller"
        value  = "true"
        effect = "NoSchedule"
      }]

      tags = merge(local.common_tags, {
        Name = "${local.cluster_name}-controller"
        Role = "Controller"
      })
    }

    jenkins_agent = {
      name = "jenkins-agent"
      instance_types = [var.agent_instance_type]
      desired_size   = 1
      min_size       = 1
      max_size       = 1

      labels = {
        role     = "agent"
        workload = "jenkins-builds"
      }

      tags = merge(local.common_tags, {
        Name = "${local.cluster_name}-agent"
        Role = "Agent"
      })
    }
  }

  cluster_addons = {
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  tags = local.common_tags
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name           = "${local.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}
locals {
  cluster_name = var.cluster_name
  common_tags = {
    Cluster     = local.cluster_name
    Terraform   = "true"
    Environment = "prod"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs = [
    "${var.aws_region}a",
    "${var.aws_region}b",
  ]

  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  eks_managed_node_groups = {
    jenkins_controller = {
      name = "jenkins-controller"
      instance_types = [var.controller_instance_type]
      desired_size   = 1
      min_size       = 1
      max_size       = 1

      labels = {
        role     = "controller"
        workload = "jenkins-master"
      }

      taints = [{
        key    = "jenkins.io/controller"
        value  = "true"
        effect = "NoSchedule"
      }]

      tags = merge(local.common_tags, {
        Name = "${local.cluster_name}-controller"
        Role = "Controller"
      })
    }

    jenkins_agent = {
      name = "jenkins-agent"
      instance_types = [var.agent_instance_type]
      desired_size   = 1
      min_size       = 1
      max_size       = 1

      labels = {
        role     = "agent"
        workload = "jenkins-builds"
      }

      tags = merge(local.common_tags, {
        Name = "${local.cluster_name}-agent"
        Role = "Agent"
      })
    }
  }

  cluster_addons = {
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  tags = local.common_tags
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name           = "${local.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

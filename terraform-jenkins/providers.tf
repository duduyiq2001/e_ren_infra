provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Jenkins"
      ManagedBy   = "Terraform"
      Environment = "prod"
      Repository  = "e_ren_infra"
    }
  }
}

data "aws_eks_cluster" "jenkins" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "jenkins" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.jenkins.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.jenkins.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.jenkins.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.jenkins.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.jenkins.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.jenkins.token
  }
}

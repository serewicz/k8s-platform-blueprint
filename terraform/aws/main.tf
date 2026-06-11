# terraform/aws/main.tf
# Production-grade EKS cluster provisioning with Karpenter prerequisites.
# Designed to be called from root or CI with tfvars per environment.
#
# Outputs standardized values expected by GitOps bootstrap and OpenCost.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      ManagedBy   = "k8s-platform-blueprint"
      Environment = var.environment
      CostCenter  = var.cost_center
      Owner       = var.owner
    }
  }
}

# VPC + networking (simplified but realistic)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "prod"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  eks_managed_node_groups = {
    # Small initial on-demand managed group for critical components.
    # Karpenter will handle the majority of capacity.
    critical = {
      min_size     = 2
      max_size     = 6
      desired_size = 3

      instance_types = ["m6i.large", "m5.large"]
      capacity_type  = "ON_DEMAND"

      labels = {
        "node-pool"                   = "on-demand-critical"
        "node.kubernetes.io/capacity-type" = "on-demand"
      }
    }
  }

  # Enable OIDC for IRSA (required for Karpenter, External Secrets, etc.)
  enable_irsa = true

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# IAM role for Karpenter (node provisioning)
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Karpenter node IAM role will be created
  create_iam_role = true
}

# Output standardized values for GitOps / bootstrap consumption
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "karpenter_iam_role_arn" {
  value = module.karpenter.iam_role_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

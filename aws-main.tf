################################################################################
# Fivetran Hybrid Deployment - AWS Sandbox
# Run from: AWS CloudShell (console.aws.amazon.com)
#
# Usage:
#   terraform init
#   terraform apply -var="region=us-west-2" -var="cluster_name=fivetran-sandbox-YOURNAME"
#   terraform destroy -var="region=us-west-2" -var="cluster_name=fivetran-sandbox-YOURNAME"
################################################################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

################################################################################
# Variables
################################################################################

variable "region" {
  description = "AWS region to deploy the cluster e.g. us-east-1, us-west-2. Must match your data source/destination region to avoid cross-region transfer costs."
  type        = string
}

variable "cluster_name" {
  description = "Unique name for your cluster - use your name/initials to avoid conflicts e.g. fivetran-sandbox-david"
  type        = string
}

################################################################################
# Provider
################################################################################

provider "aws" {
  region = var.region
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2

      tags = {
        "k8s.io/cluster-autoscaler/enabled"           = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    }
  }

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
    }
    aws-efs-csi-driver = { most_recent = true }
  }
}

################################################################################
# Cluster Autoscaler IAM
################################################################################

resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
    }]
  })
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "cluster-autoscaler"
  role = aws_iam_role.cluster_autoscaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstanceTypes"
      ]
      Resource = "*"
    }]
  })
}


################################################################################
# EBS CSI Driver IRSA
################################################################################

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

################################################################################
# EFS for ReadWriteMany PVC
################################################################################

resource "aws_efs_file_system" "fivetran" {
  tags = { Name = "${var.cluster_name}-efs" }
}

################################################################################
# Auto-configure kubectl
################################################################################

resource "null_resource" "configure_kubectl" {
  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
  }

  depends_on = [module.eks]
}

################################################################################
# Outputs
################################################################################

output "cluster_name" {
  value = var.cluster_name
}

output "region" {
  value = var.region
}

output "next_steps" {
  value = <<-EOT
    Cluster is ready and kubectl is configured!
    Verify:    kubectl get nodes
    Tear down: terraform destroy -var="region=${var.region}" -var="cluster_name=${var.cluster_name}"
  EOT
}

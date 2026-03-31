################################################################################
# Fivetran Hybrid Deployment - Multi-Cloud Sandbox
# Usage:
#   terraform init
#   terraform apply -var="cloud=aws" -var="region=us-east-1"
#   terraform destroy -var="cloud=aws"
################################################################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
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

variable "cloud" {
  description = "Target cloud provider: aws | azure | gcp"
  type        = string
  validation {
    condition     = contains(["aws", "azure", "gcp"], var.cloud)
    error_message = "cloud must be one of: aws, azure, gcp"
  }
}

variable "cluster_name" {
  description = "Name for the Kubernetes cluster"
  type        = string
  default     = "fivetran-hybrid-sandbox"
}

variable "region" {
  description = "Region to deploy the cluster. Must match your data source/destination region to avoid cross-region transfer costs. AWS: e.g. us-east-1 | Azure: e.g. eastus | GCP: e.g. us-central1"
  type        = string
}

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
  default     = ""
}

################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = var.region
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = var.gcp_project
  region  = var.region
}

################################################################################
# AWS / EKS
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  count   = var.cloud == "aws" ? 1 : 0

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc[0].vpc_id
  subnet_ids = module.vpc[0].private_subnets

  # Minimal node group for sandbox
  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2

      # Required for Cluster Autoscaler
      labels = {
        "k8s.io/cluster-autoscaler/enabled"              = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}"  = "owned"
      }
    }
  }

  cluster_addons = {
    aws-ebs-csi-driver = { most_recent = true }
    aws-efs-csi-driver = { most_recent = true }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  count   = var.cloud == "aws" ? 1 : 0

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Cost saving for sandbox
}

# EFS for ReadWriteMany PVC (required by Fivetran)
resource "aws_efs_file_system" "fivetran" {
  count = var.cloud == "aws" ? 1 : 0
  tags  = { Name = "${var.cluster_name}-efs" }
}

# Cluster Autoscaler IAM role for EKS
resource "aws_iam_role" "cluster_autoscaler" {
  count = var.cloud == "aws" ? 1 : 0
  name  = "${var.cluster_name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks[0].oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
    }]
  })
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count = var.cloud == "aws" ? 1 : 0
  name  = "cluster-autoscaler"
  role  = aws_iam_role.cluster_autoscaler[0].id

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
# Azure / AKS
################################################################################

resource "azurerm_resource_group" "fivetran" {
  count    = var.cloud == "azure" ? 1 : 0
  name     = "${var.cluster_name}-rg"
  location = var.region
}

resource "azurerm_kubernetes_cluster" "fivetran" {
  count               = var.cloud == "azure" ? 1 : 0
  name                = var.cluster_name
  location            = azurerm_resource_group.fivetran[0].location
  resource_group_name = azurerm_resource_group.fivetran[0].name
  dns_prefix          = var.cluster_name

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_D2_v2"
    enable_auto_scaling = true  # Cluster Autoscaler
    min_count           = 1
    max_count           = 5
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure Files for ReadWriteMany PVC
  storage_profile {
    file_driver_enabled = true
  }
}

################################################################################
# GCP / GKE
################################################################################

resource "google_container_cluster" "fivetran" {
  count    = var.cloud == "gcp" ? 1 : 0
  name     = var.cluster_name
  location = var.region

  # Remove default node pool and use managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false # Allow easy sandbox teardown
}

resource "google_container_node_pool" "fivetran" {
  count      = var.cloud == "gcp" ? 1 : 0
  name       = "${var.cluster_name}-node-pool"
  cluster    = google_container_cluster.fivetran[0].name
  location   = var.region

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  node_config {
    machine_type = "e2-medium" # Minimal cost for sandbox
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

################################################################################
# Auto-configure kubectl after cluster is ready
################################################################################

resource "null_resource" "configure_kubectl" {
  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
    cloud        = var.cloud
  }

  provisioner "local-exec" {
    command = (
      var.cloud == "aws"   ? "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}" :
      var.cloud == "azure" ? "az aks get-credentials --resource-group ${var.cluster_name}-rg --name ${var.cluster_name} --overwrite-existing" :
                              "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.gcp_project}"
    )
  }

  depends_on = [
    module.eks,
    azurerm_kubernetes_cluster.fivetran,
    google_container_cluster.fivetran
  ]
}

################################################################################
# Outputs
################################################################################

output "cloud" {
  value = var.cloud
}

output "cluster_name" {
  value = var.cluster_name
}

output "next_steps" {
  value = <<-EOT
    Cluster is ready and kubectl is configured!
    Verify:    kubectl get nodes
    Tear down: terraform destroy -var="cloud=${var.cloud}" -var="region=${var.region}"
  EOT
}

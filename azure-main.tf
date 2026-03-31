################################################################################
# Fivetran Hybrid Deployment - Azure Sandbox
# Run from: Azure Cloud Shell (portal.azure.com)
#
# Usage:
#   terraform init
#   terraform apply -var="region=eastus" -var="cluster_name=fivetran-sandbox-YOURNAME"
#   terraform destroy -var="region=eastus" -var="cluster_name=fivetran-sandbox-YOURNAME"
################################################################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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
  description = "Azure region to deploy the cluster e.g. eastus, westus. Must match your data source/destination region to avoid cross-region transfer costs."
  type        = string
}

variable "cluster_name" {
  description = "Unique name for your cluster - use your name/initials to avoid conflicts e.g. fivetran-sandbox-david"
  type        = string
}

################################################################################
# Provider
################################################################################

provider "azurerm" {
  features {}
}

################################################################################
# Resource Group
################################################################################

resource "azurerm_resource_group" "fivetran" {
  name     = "${var.cluster_name}-rg"
  location = var.region
}

################################################################################
# AKS Cluster
################################################################################

resource "azurerm_kubernetes_cluster" "fivetran" {
  name                = var.cluster_name
  location            = azurerm_resource_group.fivetran.location
  resource_group_name = azurerm_resource_group.fivetran.name
  dns_prefix          = var.cluster_name

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_D2_v2"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5
  }

  identity {
    type = "SystemAssigned"
  }

  storage_profile {
    file_driver_enabled = true
  }
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
    command = "az aks get-credentials --resource-group ${var.cluster_name}-rg --name ${var.cluster_name} --overwrite-existing"
  }

  depends_on = [azurerm_kubernetes_cluster.fivetran]
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

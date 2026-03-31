################################################################################
# Fivetran Hybrid Deployment - GCP Sandbox
# Run from: GCP Cloud Shell (console.cloud.google.com)
#
# Usage:
#   terraform init
#   terraform apply -var="region=us-central1" -var="gcp_project=$DEVSHELL_PROJECT_ID" -var="cluster_name=fivetran-sandbox-YOURNAME"
#   terraform destroy -var="region=us-central1" -var="gcp_project=$DEVSHELL_PROJECT_ID" -var="cluster_name=fivetran-sandbox-YOURNAME"
################################################################################

terraform {
  required_version = ">= 1.3.0"

  required_providers {
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

variable "region" {
  description = "GCP region to deploy the cluster e.g. us-central1, us-east1. Must match your data source/destination region to avoid cross-region transfer costs."
  type        = string
}

variable "cluster_name" {
  description = "Unique name for your cluster - use your name/initials to avoid conflicts e.g. fivetran-sandbox-david"
  type        = string
}

variable "gcp_project" {
  description = "GCP project ID — use $DEVSHELL_PROJECT_ID in Cloud Shell"
  type        = string
}

################################################################################
# Provider
################################################################################

provider "google" {
  project = var.gcp_project
  region  = var.region
}

################################################################################
# GKE Cluster
################################################################################

resource "google_container_cluster" "fivetran" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false
}

resource "google_container_node_pool" "fivetran" {
  name     = "${var.cluster_name}-node-pool"
  cluster  = google_container_cluster.fivetran.name
  location = var.region

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

################################################################################
# Auto-configure kubectl
################################################################################

resource "null_resource" "configure_kubectl" {
  triggers = {
    cluster_name = var.cluster_name
    region       = var.region
    gcp_project  = var.gcp_project
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.gcp_project}"
  }

  depends_on = [google_container_cluster.fivetran]
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
    Tear down: terraform destroy -var="region=${var.region}" -var="gcp_project=${var.gcp_project}" -var="cluster_name=${var.cluster_name}"
  EOT
}

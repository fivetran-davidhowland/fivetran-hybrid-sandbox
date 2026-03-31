#!/bin/bash
################################################################################
# Fivetran Hybrid Deployment - Bootstrap Script
#
# Usage:
#   AWS:   curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s aws us-west-2 fivetran-sandbox-YOURNAME
#   Azure: curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s azure eastus fivetran-sandbox-YOURNAME
#   GCP:   curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s gcp us-central1 fivetran-sandbox-YOURNAME YOUR_PROJECT_ID
################################################################################

set -e

CLOUD=$1
REGION=$2
CLUSTER_NAME=$3
GCP_PROJECT=$4

################################################################################
# Validate inputs
################################################################################

if [[ -z "$CLOUD" || -z "$REGION" || -z "$CLUSTER_NAME" ]]; then
  echo ""
  echo "ERROR: Missing required parameters."
  echo ""
  echo "Usage:"
  echo "  AWS:   ... | bash -s aws us-west-2 fivetran-sandbox-YOURNAME"
  echo "  Azure: ... | bash -s azure eastus fivetran-sandbox-YOURNAME"
  echo "  GCP:   ... | bash -s gcp us-central1 fivetran-sandbox-YOURNAME YOUR_PROJECT_ID"
  echo ""
  exit 1
fi

if [[ "$CLOUD" == "gcp" && -z "$GCP_PROJECT" ]]; then
  echo ""
  echo "ERROR: GCP requires a project ID as the 4th parameter."
  echo "  GCP: ... | bash -s gcp us-central1 fivetran-sandbox-YOURNAME YOUR_PROJECT_ID"
  echo ""
  exit 1
fi

if [[ "$CLOUD" != "aws" && "$CLOUD" != "azure" && "$CLOUD" != "gcp" ]]; then
  echo ""
  echo "ERROR: cloud must be aws, azure, or gcp"
  echo ""
  exit 1
fi

echo ""
echo "========================================"
echo " Fivetran Hybrid Deployment Sandbox"
echo " Cloud:   $CLOUD"
echo " Region:  $REGION"
echo " Cluster: $CLUSTER_NAME"
echo "========================================"
echo ""

################################################################################
# Install Terraform (persists to ~/bin across CloudShell sessions)
################################################################################

if ! command -v terraform &> /dev/null; then
  echo "Installing Terraform..."
  TERRAFORM_VERSION="1.14.8"
  mkdir -p ~/bin
  curl -sO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  mv terraform ~/bin/
  rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  export PATH=$HOME/bin:$PATH
  echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
  echo "Terraform installed."
else
  echo "Terraform already installed — skipping."
fi

################################################################################
# Install Helm (AWS CloudShell only — Azure and GCP have it pre-installed)
################################################################################

if ! command -v helm &> /dev/null; then
  echo "Installing Helm..."
  curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash > /dev/null 2>&1
  echo "Helm installed."
else
  echo "Helm already installed — skipping."
fi

################################################################################
# Download the right main.tf for the target cloud
################################################################################

WORK_DIR=~/fivetran-sandbox/$CLOUD
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Downloading $CLOUD Terraform config..."
curl -sO https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/${CLOUD}-main.tf
mv ${CLOUD}-main.tf main.tf
echo "Done."

################################################################################
# Terraform init and apply
################################################################################

echo ""
echo "Initializing Terraform..."
terraform init -upgrade > /dev/null

echo ""
echo "Creating cluster — this will take 10-15 minutes..."
echo ""

if [[ "$CLOUD" == "gcp" ]]; then
  terraform apply \
    -var="region=$REGION" \
    -var="cluster_name=$CLUSTER_NAME" \
    -var="gcp_project=$GCP_PROJECT" \
    -auto-approve
else
  terraform apply \
    -var="region=$REGION" \
    -var="cluster_name=$CLUSTER_NAME" \
    -auto-approve
fi

################################################################################
# Verify
################################################################################

echo ""
echo "Verifying cluster..."
kubectl get nodes

echo ""
echo "========================================"
echo " Cluster is ready!"
echo ""
echo " To tear down:"
if [[ "$CLOUD" == "gcp" ]]; then
echo "   cd ~/fivetran-sandbox/$CLOUD"
echo "   terraform destroy -var=\"region=$REGION\" -var=\"cluster_name=$CLUSTER_NAME\" -var=\"gcp_project=$GCP_PROJECT\""
else
echo "   cd ~/fivetran-sandbox/$CLOUD"
echo "   terraform destroy -var=\"region=$REGION\" -var=\"cluster_name=$CLUSTER_NAME\""
fi
echo "========================================"
echo ""

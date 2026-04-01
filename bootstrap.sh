#!/bin/bash
################################################################################
# Fivetran Hybrid Deployment - Bootstrap Script
#
# Create:
#   AWS:   curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s aws us-west-2 fivetran-sandbox-YOURNAME
#   Azure: curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s azure eastus fivetran-sandbox-YOURNAME
#   GCP:   curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s gcp us-central1 fivetran-sandbox-YOURNAME
#
# Delete:
#   AWS:   curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s aws us-west-2 fivetran-sandbox-YOURNAME -delete
#   Azure: curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s azure eastus fivetran-sandbox-YOURNAME -delete
#   GCP:   curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s gcp us-central1 fivetran-sandbox-YOURNAME -delete
################################################################################

set -e

CLOUD=$1
REGION=$2
CLUSTER_NAME=$3
ACTION=$4

# Auto-detect GCP project from environment
GCP_PROJECT=${DEVSHELL_PROJECT_ID:-""}

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
  echo "  GCP:   ... | bash -s gcp us-central1 fivetran-sandbox-YOURNAME"
  echo ""
  echo "To delete:"
  echo "  Add -delete as the last parameter"
  echo ""
  exit 1
fi

if [[ "$CLOUD" != "aws" && "$CLOUD" != "azure" && "$CLOUD" != "gcp" ]]; then
  echo "ERROR: cloud must be aws, azure, or gcp"
  exit 1
fi

if [[ "$CLOUD" == "gcp" && -z "$GCP_PROJECT" ]]; then
  echo "ERROR: Could not detect GCP project. Make sure you are running in GCP Cloud Shell."
  exit 1
fi

# Working directory scoped to cloud AND cluster name so multiple clusters coexist
WORK_DIR=~/fivetran-sandbox/$CLOUD/$CLUSTER_NAME

echo ""
echo "========================================"
echo " Fivetran Hybrid Deployment Sandbox"
echo " Cloud:   $CLOUD"
echo " Region:  $REGION"
echo " Cluster: $CLUSTER_NAME"
if [[ "$ACTION" == "-delete" ]]; then
echo " Action:  DELETE"
else
echo " Action:  CREATE"
fi
echo "========================================"
echo ""

################################################################################
# DELETE
################################################################################

if [[ "$ACTION" == "-delete" ]]; then

  if [[ ! -d "$WORK_DIR" ]]; then
    echo "ERROR: No cluster state found at $WORK_DIR"
    echo "Nothing to delete."
    exit 1
  fi

  cd $WORK_DIR

  # Make sure terraform is available
  export PATH=$HOME/bin:$PATH
  if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    TERRAFORM_VERSION="1.14.8"
    mkdir -p ~/bin
    curl -sO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    mv terraform ~/bin/
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  fi

  echo "Destroying cluster $CLUSTER_NAME..."
  echo ""

  if [[ "$CLOUD" == "gcp" ]]; then
    terraform destroy \
      -var="region=$REGION" \
      -var="cluster_name=$CLUSTER_NAME" \
      -var="gcp_project=$GCP_PROJECT" \
      -auto-approve
  else
    terraform destroy \
      -var="region=$REGION" \
      -var="cluster_name=$CLUSTER_NAME" \
      -auto-approve
  fi

  echo ""
  echo "Cleaning up state files..."
  cd ~
  rm -rf $WORK_DIR

  echo ""
  echo "========================================"
  echo " Cluster $CLUSTER_NAME deleted and"
  echo " all state files removed."
  echo "========================================"
  echo ""
  exit 0
fi

################################################################################
# CREATE
################################################################################

# Check if cluster already exists
if [[ -d "$WORK_DIR" && -f "$WORK_DIR/terraform.tfstate" ]]; then
  echo "WARNING: State file already exists for $CLUSTER_NAME."
  echo "It looks like this cluster may already be running."
  echo "Check the AWS console to confirm before creating again."
  echo ""
  echo "To delete it first run:"
  echo "  curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s $CLOUD $REGION $CLUSTER_NAME -delete"
  echo ""
  exit 1
fi

mkdir -p $WORK_DIR
cd $WORK_DIR

################################################################################
# Install Terraform (persists to ~/bin across CloudShell sessions)
################################################################################

export PATH=$HOME/bin:$PATH
if ! command -v terraform &> /dev/null; then
  echo "Installing Terraform..."
  TERRAFORM_VERSION="1.14.8"
  mkdir -p ~/bin
  curl -sO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  mv terraform ~/bin/
  rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
  echo "Terraform installed."
else
  echo "Terraform already installed — skipping."
fi

################################################################################
# Install Helm (persists — AWS CloudShell needs it, Azure/GCP have it)
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
echo " To delete when done:"
echo "   curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s $CLOUD $REGION $CLUSTER_NAME -delete"
echo "========================================"
echo ""

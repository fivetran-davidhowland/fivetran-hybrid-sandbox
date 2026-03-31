# Fivetran Hybrid Deployment — Multi-Cloud Sandbox

Provisions a Kubernetes cluster on AWS, Azure, or GCP ready for Fivetran Hybrid Deployment.
kubectl is automatically configured at the end of `terraform apply` — no extra steps.

> **Always specify `region` explicitly.** Running your cluster in the wrong region relative to your data sources and destinations will incur significant cross-region data transfer costs.

---

# AWS Setup

> **All commands below are run inside AWS CloudShell.**
> Open it at https://console.aws.amazon.com → click the `>_` icon in the top nav bar.

### Step 1 — Install Terraform and Helm
> **Run in: AWS CloudShell**
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 2 — Clone, Init, Apply, and Verify
> **Run in: AWS CloudShell** (your AWS account is auto-detected from your session)
```bash
git clone https://github.com/fivetran-davidhowland/fivetran-hybrid-sandbox.git
cd fivetran-hybrid-sandbox
terraform init
terraform apply -var="cloud=aws" -var="region=us-east-1"
# kubectl is configured automatically — just verify:
kubectl get nodes
```

### Tear Down
> **Run in: AWS CloudShell**
```bash
terraform destroy -var="cloud=aws" -var="region=us-east-1"
```

---

# Azure Setup

> **All commands below are run inside Azure Cloud Shell.**
> Open it at https://portal.azure.com → click the `>_` icon in the top nav bar → choose **Bash**.
> Terraform and Helm are pre-installed. Your subscription is auto-detected from your session.

### Step 1 — Clone, Init, Apply, and Verify
> **Run in: Azure Cloud Shell** (your Azure subscription is auto-detected from your session)
```bash
git clone https://github.com/fivetran-davidhowland/fivetran-hybrid-sandbox.git
cd fivetran-hybrid-sandbox
terraform init
terraform apply -var="cloud=azure" -var="region=eastus"
# kubectl is configured automatically — just verify:
kubectl get nodes
```

### Tear Down
> **Run in: Azure Cloud Shell**
```bash
terraform destroy -var="cloud=azure" -var="region=eastus"
```

---

# GCP Setup

> **All commands below are run inside GCP Cloud Shell.**
> Open it at https://console.cloud.google.com → click the `>_` icon in the top right.
> Terraform and Helm are pre-installed. Your project is auto-detected from your session via `$DEVSHELL_PROJECT_ID`.

### Step 1 — Clone, Init, Apply, and Verify
> **Run in: GCP Cloud Shell** (your GCP project is auto-detected from your session)
```bash
git clone https://github.com/fivetran-davidhowland/fivetran-hybrid-sandbox.git
cd fivetran-hybrid-sandbox
terraform init
terraform apply -var="cloud=gcp" -var="region=us-central1" -var="gcp_project=$DEVSHELL_PROJECT_ID"
# kubectl is configured automatically — just verify:
kubectl get nodes
```

### Tear Down
> **Run in: GCP Cloud Shell**
```bash
terraform destroy -var="cloud=gcp" -var="region=us-central1" -var="gcp_project=$DEVSHELL_PROJECT_ID"
```

---

## Parameters

| Parameter | Required | Description | Example values |
|-----------|----------|-------------|----------------|
| `cloud` | Yes | Target cloud | `aws` / `azure` / `gcp` |
| `region` | Yes | Region to deploy — must match your data source/destination region to avoid cross-region transfer costs | AWS: `us-east-1`, `us-west-2` · Azure: `eastus`, `westus` · GCP: `us-central1`, `us-east1` |
| `gcp_project` | GCP only | GCP project ID | Use `$DEVSHELL_PROJECT_ID` in Cloud Shell |
| `cluster_name` | No | Name for the cluster (default: `fivetran-hybrid-sandbox`) | Any string |

---

## What Gets Created

| Resource | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Kubernetes cluster | EKS | AKS | GKE |
| Autoscaler | Cluster Autoscaler | Built-in | Built-in |
| Node size | t3.medium | Standard_D2_v2 | e2-medium |
| Min/Max nodes | 1 / 5 | 1 / 5 | 1 / 5 |
| Storage (PVC) | EFS | Azure Files | Filestore |

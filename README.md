# Fivetran Hybrid Deployment — Multi-Cloud Sandbox

Provisions a Kubernetes cluster ready for Fivetran Hybrid Deployment.
Each cloud has its own folder — only the providers you need are downloaded.
kubectl is automatically configured at the end of `terraform apply`.

> **Always specify `region` to match your data source/destination and avoid cross-region transfer costs.**

---

# AWS Setup

> **Run in: AWS CloudShell** — https://console.aws.amazon.com → click `>_` in the top nav bar

### Step 1 — Install Terraform and Helm
> **Run in: AWS CloudShell**
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 2 — Clone, Init, Apply, and Verify
> **Run in: AWS CloudShell**
```bash
git clone https://github.com/fivetran-davidhowland/fivetran-hybrid-sandbox.git
cd fivetran-hybrid-sandbox/aws
terraform init
terraform apply -var="region=us-west-2" -var="cluster_name=fivetran-sandbox-YOURNAME"
kubectl get nodes
```

### Tear Down
> **Run in: AWS CloudShell**
```bash
terraform destroy -var="region=us-west-2" -var="cluster_name=fivetran-sandbox-YOURNAME"
```

---

# Azure Setup

> **Run in: Azure Cloud Shell** — https://portal.azure.com → click `>_` in the top nav bar → choose **Bash**
> Terraform and Helm are pre-installed. Your subscription is auto-detected from your session.

### Step 1 — Clone, Init, Apply, and Verify
> **Run in: Azure Cloud Shell**
```bash
git clone https://github.com/fivetran-davidhowland/fivetran-hybrid-sandbox.git
cd fivetran-hybrid-sandbox/azure
terraform init
terraform apply -var="region=eastus" -var="cluster_name=fivetran-sandbox-YOURNAME"
kubectl get nodes
```

### Tear Down
> **Run in: Azure Cloud Shell**
```bash
terraform destroy -var="region=eastus" -var="cluster_name=fivetran-sandbox-YOURNAME"
```

---

# GCP Setup

> **Run in: GCP Cloud Shell** — https://console.cloud.google.com → click `>_` in the top right
> Terraform and Helm are pre-installed. Your project is auto-detected via `$DEVSHELL_PROJECT_ID`.

### Step 1 — Clone, Init, Apply, and Verify
> **Run in: GCP Cloud Shell**
```bash
git clone https://github.com/fivetran-davidhowland/fivetran-hybrid-sandbox.git
cd fivetran-hybrid-sandbox/gcp
terraform init
terraform apply -var="region=us-central1" -var="gcp_project=$DEVSHELL_PROJECT_ID" -var="cluster_name=fivetran-sandbox-YOURNAME"
kubectl get nodes
```

### Tear Down
> **Run in: GCP Cloud Shell**
```bash
terraform destroy -var="region=us-central1" -var="gcp_project=$DEVSHELL_PROJECT_ID" -var="cluster_name=fivetran-sandbox-YOURNAME"
```

---

## Parameters

| Parameter | Required | Description | Example values |
|-----------|----------|-------------|----------------|
| `region` | Yes | Region to deploy — must match your data source/destination to avoid cross-region transfer costs | AWS: `us-east-1`, `us-west-2` · Azure: `eastus`, `westus` · GCP: `us-central1`, `us-east1` |
| `cluster_name` | Yes | Your unique cluster name — use your name/initials to avoid conflicts | `fivetran-sandbox-david` |
| `gcp_project` | GCP only | GCP project ID | Use `$DEVSHELL_PROJECT_ID` in Cloud Shell |

---

## What Gets Created

| Resource | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Kubernetes cluster | EKS | AKS | GKE |
| Autoscaler | Cluster Autoscaler | Built-in | Built-in |
| Node size | t3.medium | Standard_D2_v2 | e2-medium |
| Min/Max nodes | 1 / 5 | 1 / 5 | 1 / 5 |
| Storage (PVC) | EFS | Azure Files | Filestore |

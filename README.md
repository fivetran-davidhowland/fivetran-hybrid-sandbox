# Fivetran Hybrid Deployment — Multi-Cloud Sandbox

Provisions a Kubernetes cluster on AWS, Azure, or GCP ready for Fivetran Hybrid Deployment.

> **Always use your name in `cluster_name` to avoid conflicts with other users.**
> **Always specify `region` to match your data source/destination and avoid cross-region transfer costs.**

---

## AWS

> **Run in: AWS CloudShell** — https://console.aws.amazon.com → click `>_` in the top nav bar

```bash
curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s aws us-west-2 fivetran-sandbox-YOURNAME
```

---

## Azure

> **Run in: Azure Cloud Shell** — https://portal.azure.com → click `>_` in the top nav bar → choose **Bash**

```bash
curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s azure eastus fivetran-sandbox-YOURNAME
```

---

## GCP

> **Run in: GCP Cloud Shell** — https://console.cloud.google.com → click `>_` in the top right

```bash
curl -s https://raw.githubusercontent.com/fivetran-davidhowland/fivetran-hybrid-sandbox/main/bootstrap.sh | bash -s gcp us-central1 fivetran-sandbox-YOURNAME $DEVSHELL_PROJECT_ID
```

---

## Tear Down

> **Run in: the same Cloud Shell you used to create it**

```bash
cd ~/fivetran-sandbox/aws   # or azure / gcp
terraform destroy -var="region=REGION" -var="cluster_name=fivetran-sandbox-YOURNAME"
# GCP only: add -var="gcp_project=$DEVSHELL_PROJECT_ID"
```

---

## Parameters

| Parameter | Required | Description | Example values |
|-----------|----------|-------------|----------------|
| `cloud` | Yes | Target cloud | `aws` / `azure` / `gcp` |
| `region` | Yes | Must match your data source/destination region to avoid cross-region transfer costs | AWS: `us-east-1`, `us-west-2` · Azure: `eastus`, `westus` · GCP: `us-central1`, `us-east1` |
| `cluster_name` | Yes | Your unique cluster name — use your name/initials | `fivetran-sandbox-david` |
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

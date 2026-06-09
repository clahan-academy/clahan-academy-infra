# Clahan-Academy Online Exam Platform Infrastructure (Active-Standby DR)

This directory contains the production-grade, multi-region Terraform project for the Clahan-Academy Online Exam Platform. It implements an **Active-Standby Disaster Recovery (DR)** architecture across two Azure regions:
* **Primary / Active Region:** Central India (centralindia)
* **Secondary / Standby Region:** Southeast Asia (southeastasia)

---

## Architecture Overview

```
                      +-----------------------------+
                      |      Azure Front Door       |
                      |    (ep-clahan-global)       |
                      +--------------+--------------+
                                     |
              +----------------------+----------------------+
              | (Priority 1)                                | (Priority 2, failover target)
              v                                             v
    +-------------------+                         +-------------------+
    |    App Gateway    |                         |    App Gateway    |
    |  (India, Active)  |                         |   (SEA, Standby)  |
    +---------+---------+                         +---------+---------+
              |                                             |
              v (snet-containerapp)                         v (snet-containerapp)
    +-------------------+                         +-------------------+
    |  Container Apps   |                         |  Container Apps   |
    |  (min_replicas=1) |                         |  (min_replicas=0) |
    +----+----+----+----+                         +----+----+----+----+
         |    |    |                                   |    |    |
   +-----+    |    +-----+                       +-----+    |    +-----+
   |          |          |                       |          |          |
   v          v          v                       v          v          v
 +----+     +----+     +----+                  +----+     +----+     +----+
 | KV |     | SB |     |Red |                  | KV |     | SB |     |Red |
 +----+     +----+     +----+                  +----+     +----+     +----+
   |                                             |
   v                                             v
 +----+                                        +----+
 | PG |=======(Async Geo-Replication)=========>| PG | (Read Replica,
 |Main|                                        |Repl|  promoted on DR)
 +----+                                        +----+
```

### Key Highlights
* **Multi-Environment Workspaces:** Isolated deployments using Terraform workspaces (`dev`, `staging`, `prod`) and dedicated environment variable files (`.tfvars`).
* **Global Routing:** Azure Front Door routes incoming traffic based on latency and health probes.
* **Cost Efficiency:** Standby region microservices are configured with `min_replicas = 0`, consuming zero compute cost until promoted.
* **Data Protection:** PostgreSQL Flexible Server uses cross-region asynchronous streaming replication.
* **Independent Networking:** No VNet peering is used, isolating failure domains. Communication is public-facing/Front Door based.
* **Observability:** Centralized Log Analytics Workspace and Application Insights collect telemetry from both regions.

---

## Prerequisites

1. **Azure CLI:** Installed and authenticated.
   ```bash
   az login
   ```
2. **Terraform:** Version `>= 1.5.0` installed.
3. **Docker Hub Images:** The 11 microservice images must be available under `vignesh8386/clahan-*` or public registries.

---

## Step 1: Remote Backend Setup (Bootstrap)

Before initializing Terraform, you must create the Azure Storage resources to store the state file. Run the provided bootstrap script:

```bash
cd scripts
chmod +x *.sh
./bootstrap-backend.sh
```

This script will automatically:
1. Create a dedicated resource group `rg-clahan-tfstate`.
2. Provision a globally-unique storage account `stclahantfstate<random4>`.
3. Create the `tfstate` blob container with Azure AD auth enabled.
4. Update `backend.tf` to reference the newly created storage account.

---

## Step 2: Initialize & Configure Workspaces

Initialize Terraform and create the required workspaces (`dev`, `staging`, `prod`):

```bash
./init-workspaces.sh
```

This will run `terraform init`, create the workspaces if they do not exist, and select the `dev` workspace as active.

To manually manage workspaces, use:
```bash
# List all workspaces
terraform workspace list

# Select a workspace
terraform workspace select <workspace_name>

# Create a new workspace
terraform workspace new <workspace_name>
```

---

## Step 3: Deploying the Infrastructure

To deploy the infrastructure, run the following commands from the root `terraform` folder.

> [!WARNING]
> During heavy initial deployments, network latency or rate-limiting on Azure endpoints can cause timeouts. To prevent this, always deploy using the `-parallelism=5` flag to restrict concurrent operations:
> ```bash
> terraform plan -var-file=environments/dev.tfvars -out tfplan
> terraform apply -parallelism=5 tfplan
> ```

Replace `dev.tfvars` with the target environment configuration (e.g., `staging.tfvars` or `prod.tfvars`) and make sure the active workspace matches!

---

## Step 4: Verification

1. **Get the Entry Point URL:**
   ```bash
   terraform output frontdoor_url
   ```
2. **Verify in Browser:**
   Open the returned URL in your web browser. Traffic will automatically route to the Central India region.

---

## Disaster Recovery (DR) Testing

Detailed manual and automated failover steps, along with return-to-normal (failback) operational steps, are located in the [DR Runbook](DR_RUNBOOK.md).

To run a manual local failover, use the provided CLI helper script:
```bash
./scripts/failover-dr.sh <environment>
```

---

## Cost Estimate Breakdown

The monthly cost of running this active-standby architecture in Azure:

| Resource | Configuration | Region(s) | Estimated Monthly Cost |
| :--- | :--- | :--- | :--- |
| **Application Gateway** | WAF_v2, 2 instances autoscale | Both (2) | ~$520.00 |
| **PostgreSQL Flexible** | GP_Standard_D4s_v3 (4 vCore, 16GB) | Both (1 Main + 1 Replica) | ~$540.00 |
| **Azure Cache for Redis** | Standard C1 (1 GB) | Both (2) | ~$80.00 |
| **Azure Service Bus** | Premium Tier (1 CU) | Both (2) | ~$650.00 |
| **Container Apps** | 11 services, Serverless | Both (Standby is 0 CPU) | ~$50.00 |
| **Azure Front Door** | Standard Tier | Global (1) | ~$35.00 |
| **Monitoring & Logging** | LAW + App Insights Pay-as-you-go | Global (1) | ~$30.00 |
| **Functions & Webhooks** | Consumption | Both (2) | ~$5.00 |
| **TOTAL** | | | **~$1,910.00 / month** |

> [!TIP]
> For demo and learning purposes, run `terraform destroy` immediately after testing to keep your actual Azure expenditures under $5.00.

---

## Cleanup

To completely remove all provisioned resources and stop incurring costs:
```bash
terraform destroy -var-file=environments/dev.tfvars -auto-approve
```

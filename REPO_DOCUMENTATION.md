# 🏗️ Clahan Academy V2 - Infrastructure Repository Documentation

This repository contains the **Infrastructure as Code (IaC)** files written in Terraform to provision, configure, and maintain the Azure cloud resources required for **Clahan Academy V2**.

---

## 📂 Repository Layout

```
clahan-academy-infra/
├── main.tf                 # Orchestration of all child modules
├── variables.tf            # Variables definitions (SKUs, node sizes, settings)
├── outputs.tf              # Resource IDs, endpoints, and credentials outputs
├── providers.tf            # Azure provider declaration
├── backend.tf              # Configures Azure Storage remote state backend
├── environments/           # Environment parameter files
│   ├── dev.tfvars.example  # Template variables for Development env
│   └── prod.tfvars.example # Template variables for Production env
├── scripts/
│   └── bootstrap.sh        # Automates subscription setup & credential generation
└── modules/                # Reusable resource modules
    ├── acr/                # Azure Container Registry (ACR)
    ├── aks/                # Azure Kubernetes Service (AKS)
    ├── functions/          # Azure Functions Health Check timer triggers
    ├── identity/           # Workload Identity & Federated credentials
    ├── jumpvm/             # Jumpbox VM for administration
    ├── keyvault/           # Key Vault storage and access policy
    ├── monitoring/         # Log Analytics & Alert notifications
    ├── networking/         # VNet, Subnets, and Private Endpoints
    ├── postgres/           # PostgreSQL Flexible Server private database
    ├── redis/              # Azure Cache for Redis private cluster
    └── storage/            # Blob storage accounts for asset storage
```

---

## 🛠️ Modules Breakdown

### 1. Networking (`networking`)
*   Creates a core virtual network (VNet) partitioned into specialized subnets:
    *   `aks-subnet`: Subnet dedicated to Kubernetes cluster nodes.
    *   `mgmt-subnet`: Subnet housing the management jumpbox VM.
    *   `pe-subnet`: Subnet dedicated to Private Endpoints.
*   Sets up Private DNS Zones to resolve internal database, Redis, Key Vault, and storage endpoints privately.

### 2. Kubernetes (`aks`)
*   Provisions an AKS cluster with OIDC Issuer enabled (required for Workload Identity).
*   Configures a system node pool for base cluster resources and handles horizontal scaling for application pods.
*   Enables Container Insights integrated with the Log Analytics Workspace.

### 3. Identity (`identity`)
*   Leverages **Azure Workload Identity** to assign User Assigned Managed Identities to individual Kubernetes service accounts (e.g. `auth-sa`, `exam-sa`).
*   Sets up Federated Credentials to map Kubernetes service account tokens to Azure Active Directory, enabling passwordless authentication.

### 4. Key Vault (`keyvault`)
*   Provisions a central HSM/Software Key Vault to safely store secrets.
*   Initializes default secrets: SMTP hosts/ports, SendGrid APIs, storage keys, and database connection strings.

### 5. PostgreSQL & Redis (`postgres`, `redis`)
*   Deploys Azure Database for PostgreSQL Flexible Server inside the private subnet.
*   Deploys Azure Cache for Redis for high-speed queue handling and caching.
*   Configures Private Endpoints to ensure they cannot be accessed from the public internet.

---

## 🚀 Deployment & Bootstrapping

### Step 1: Bootstrap Azure Subscription
Run the bootstrap script to create the Terraform remote state backend and prepare the GitHub Actions service principal:
```bash
bash scripts/bootstrap.sh
```
This script creates a resource group `rg-clahan-tfstate`, a storage account `stclahantfstate`, and outputs the configuration values to `.bootstrap-output.txt`.

### Step 2: Configure Environment Variables
Copy and fill the `.tfvars` file for your target environment:
```bash
cp environments/dev.tfvars.example environments/dev.tfvars
# Open dev.tfvars and insert client IDs and secrets from .bootstrap-output.txt
```

### Step 3: Run Terraform
Initialize and apply the configuration:
```bash
terraform init
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```
Alternatively, commit and push changes to trigger the GitHub Actions workflow (`.github/workflows/terraform-apply.yml`).

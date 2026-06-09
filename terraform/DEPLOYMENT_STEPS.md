# Clahan-Academy Terraform Workspace Deployment Steps

This guide outlines the systematic procedure for managing the multi-environment infrastructure using **Terraform Workspaces** and environment variable files (`.tfvars`).

---

## 1. Initial Setup & Initialization

Ensure you are authenticated to Azure via the CLI:
```powershell
az login
```

Initialize Terraform (pointing to the shared remote storage backend):
```powershell
cd terraform
terraform init -reconfigure
```

---

## 2. Managing Workspaces

Workspaces allow you to manage isolated state files for each environment (`dev`, `staging`, `prod`) under a single configuration directory.

### Create Workspaces (One-time only)
```powershell
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

### List Workspaces
```powershell
terraform workspace list
```

### Select a Workspace
```powershell
terraform workspace select dev
```

---

## 3. Deployment Steps (Systematic Apply)

Always verify your active workspace matches the `.tfvars` file you are passing to prevent environment cross-talk.

### Development Environment (`dev`)
```powershell
# 1. Switch to the dev workspace
terraform workspace select dev

# 2. Generate and save the dev execution plan (using space-separated flags for PowerShell)
terraform plan -var-file "environments/dev.tfvars" -out dev.tfplan

# 3. Apply the plan using restricted parallelism to avoid Azure rate limits/timeouts
terraform apply -parallelism 5 dev.tfplan
```

### Staging Environment (`staging`)
```powershell
# 1. Switch to the staging workspace
terraform workspace select staging

# 2. Generate and save the staging execution plan
terraform plan -var-file "environments/staging.tfvars" -out staging.tfplan

# 3. Apply the plan
terraform apply -parallelism 5 staging.tfplan
```

### Production Environment (`prod`)
```powershell
# 1. Switch to the prod workspace
terraform workspace select prod

# 2. Generate and save the prod execution plan
terraform plan -var-file "environments/prod.tfvars" -out prod.tfplan

# 3. Apply the plan
terraform apply -parallelism 5 prod.tfplan
```

---

## 4. Teardown Steps (Systematic Destroy)

To tear down an environment completely, select the target workspace first and execute the destroy plan.

### Destroy Development (`dev`)
```powershell
# 1. Select the dev workspace
terraform workspace select dev

# 2. Generate a destroy plan
terraform plan -destroy -var-file "environments/dev.tfvars" -out destroy-dev.tfplan

# 3. Apply the destroy plan
terraform apply destroy-dev.tfplan
```

### Destroy Staging (`staging`)
```powershell
# 1. Select the staging workspace
terraform workspace select staging

# 2. Generate a destroy plan
terraform plan -destroy -var-file "environments/staging.tfvars" -out destroy-staging.tfplan

# 3. Apply the destroy plan
terraform apply destroy-staging.tfplan
```

### Destroy Production (`prod`)
```powershell
# 1. Select the prod workspace
terraform workspace select prod

# 2. Generate a destroy plan
terraform plan -destroy -var-file "environments/prod.tfvars" -out destroy-prod.tfplan

# 3. Apply the destroy plan
terraform apply destroy-prod.tfplan
```

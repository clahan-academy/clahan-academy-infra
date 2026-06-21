# clahan-academy-infra/scripts/bootstrap.ps1
# PowerShell script to bootstrap Azure resources and OIDC trust for Clahan Academy

$Location = "eastus2"
$TfResourceGroup = "rg-clahan-tfstate"
$TfStorageAccountBase = "stclahantfstate"
$SpName = "sp-github-clahan-ci"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   SECTION 1: Prerequisites Check"
Write-Host "============================================" -ForegroundColor Cyan

function Check-Tool {
    param(
        [string]$ToolName,
        [string]$InstallUrl
    )
    if (Get-Command $ToolName -ErrorAction SilentlyContinue) {
        $Version = & $ToolName --version 2>$null | Select-Object -First 1
        Write-Host "[OK] $ToolName found: $Version" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] $ToolName not found. Please install from: $InstallUrl" -ForegroundColor Red
        Exit 1
    }
}

Check-Tool "az" "https://docs.microsoft.com/cli/azure/install-azure-cli"
Check-Tool "terraform" "https://developer.hashicorp.com/terraform/downloads"
Check-Tool "git" "https://git-scm.com/downloads"
Check-Tool "helm" "https://helm.sh/docs/intro/install/"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   SECTION 2: Azure Login & Subscription"
Write-Host "============================================" -ForegroundColor Cyan

if (-not (az account show --query name -o tsv 2>$null)) {
    Write-Host "[INFO] Not logged in. Opening browser..." -ForegroundColor Cyan
    az login | Out-Null
}

$SubscriptionId = (az account show --query id -o tsv)
$TenantId = (az account show --query tenantId -o tsv)
$SubName = (az account show --query name -o tsv)

# Generate a globally unique storage account name by appending the subscription ID hash
$SubSuffix = $SubscriptionId.Split("-")[0]
$TfStorageAccount = "$TfStorageAccountBase$SubSuffix"

Write-Host "[INFO] Using subscription: $SubName ($SubscriptionId)" -ForegroundColor Green
Write-Host "[INFO] Using Tenant: $TenantId" -ForegroundColor Green
Write-Host "[INFO] Generated storage name: $TfStorageAccount" -ForegroundColor Green

$Confirm = Read-Host "Is this subscription correct? (y/n)"
if ($Confirm -ne "y" -and $Confirm -ne "Y") {
    Write-Host "[ERROR] Aborted. Please log into the correct Azure subscription and run again." -ForegroundColor Red
    Exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   SECTION 3: Create Terraform Backend State Storage"
Write-Host "============================================" -ForegroundColor Cyan

# Create Resource Group
if (az group show --name $TfResourceGroup 2>$null) {
    Write-Host "[WARN] Resource group $TfResourceGroup already exists, skipping" -ForegroundColor Yellow
} else {
    az group create --name $TfResourceGroup --location $Location --tags project=clahan-academy purpose=terraform-state | Out-Null
    Write-Host "[OK] Resource group created: $TfResourceGroup" -ForegroundColor Green
}

# Create Storage Account
if (az storage account show --name $TfStorageAccount --resource-group $TfResourceGroup 2>$null) {
    Write-Host "[WARN] Storage account $TfStorageAccount already exists, skipping" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Creating storage account $TfStorageAccount..." -ForegroundColor Cyan
    $ErrorActionPreference = "Continue"
    az storage account create --name $TfStorageAccount --resource-group $TfResourceGroup --location $Location --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false --tags project=clahan-academy purpose=terraform-state | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to create storage account. Please check if name is valid." -ForegroundColor Red
        Exit 1
    }
    Write-Host "[OK] Storage account created: $TfStorageAccount" -ForegroundColor Green
}

# Create Container
if (az storage container show --name $TfContainer --account-name $TfStorageAccount 2>$null) {
    Write-Host "[WARN] Container $TfContainer already exists, skipping" -ForegroundColor Yellow
} else {
    az storage container create --name $TfContainer --account-name $TfStorageAccount --public-access off | Out-Null
    Write-Host "[OK] Blob container created: $TfContainer" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   SECTION 4: GitHub Actions Service Principal & OIDC"
Write-Host "============================================" -ForegroundColor Cyan

$AppId = (az ad app list --display-name $SpName --query "[0].appId" -o tsv 2>$null)
if (-not $AppId -or $AppId -eq "null" -or $AppId -eq "") {
    $AppId = (az ad app create --display-name $SpName --query appId -o tsv)
    Write-Host "[OK] App registration created: $SpName ($AppId)" -ForegroundColor Green
} else {
    Write-Host "[WARN] App registration $SpName already exists ($AppId)" -ForegroundColor Yellow
}

$SpObjectId = (az ad sp show --id $AppId --query id -o tsv 2>$null)
if (-not $SpObjectId -or $SpObjectId -eq "null" -or $SpObjectId -eq "") {
    az ad sp create --id $AppId | Out-Null
    $SpObjectId = (az ad sp show --id $AppId --query id -o tsv)
    Write-Host "[OK] Service principal created" -ForegroundColor Green
} else {
    Write-Host "[WARN] Service principal already exists" -ForegroundColor Yellow
}

$RoleExists = (az role assignment list --assignee $AppId --role "Contributor" --scope "/subscriptions/$SubscriptionId" --query "[0].id" -o tsv 2>$null)
if (-not $RoleExists -or $RoleExists -eq "null" -or $RoleExists -eq "") {
    Write-Host "[INFO] Assigning Contributor role to Service Principal..." -ForegroundColor Cyan
    az role assignment create --role "Contributor" --assignee $AppId --scope "/subscriptions/$SubscriptionId" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Red
        Write-Host "[ERROR] AuthorizationFailed: You do not have permissions to write role assignments." -ForegroundColor Red
        Write-Host "To resolve this, please ask your Azure Subscription Administrator to grant you" -ForegroundColor Yellow
        Write-Host "the 'User Access Administrator' or 'Owner' role on this subscription." -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Red
    } else {
        Write-Host "[OK] Contributor role assigned" -ForegroundColor Green
    }
} else {
    Write-Host "[WARN] Contributor role already assigned" -ForegroundColor Yellow
}

function Create-FederatedCredential {
    param(
        [string]$CredName,
        [string]$Subject
    )
    if (az ad app federated-credential show --id $AppId --federated-credential-id $CredName 2>$null) {
        Write-Host "[WARN] Federated credential $CredName already exists, skipping" -ForegroundColor Yellow
    } else {
        $ParamsObj = @{
            name = $CredName
            issuer = "https://token.actions.githubusercontent.com"
            subject = $Subject
            description = "Federated credential for $CredName"
            audiences = @("api://AzureADTokenExchange")
        }
        $ParamsJson = $ParamsObj | ConvertTo-Json -Compress
        $TempFile = [System.IO.Path]::GetTempFileName()
        $ParamsJson | Out-File -FilePath $TempFile -Encoding ascii
        az ad app federated-credential create --id $AppId --parameters "@$TempFile" | Out-Null
        Remove-Item $TempFile
        Write-Host "[OK] Federated credential $CredName created" -ForegroundColor Green
    }
}

Create-FederatedCredential "github-app-main" "repo:clahan-academy/clahan-academy-app:ref:refs/heads/main"
Create-FederatedCredential "github-app-pr" "repo:clahan-academy/clahan-academy-app:pull_request"
Create-FederatedCredential "github-app-feature" "repo:clahan-academy/clahan-academy-app:ref:refs/heads/feature/*"

Create-FederatedCredential "github-infra-main" "repo:clahan-academy/clahan-academy-infra:ref:refs/heads/main"
Create-FederatedCredential "github-infra-pr" "repo:clahan-academy/clahan-academy-infra:pull_request"
Create-FederatedCredential "github-infra-feature" "repo:clahan-academy/clahan-academy-infra:ref:refs/heads/feature/*"

Create-FederatedCredential "github-helm-main" "repo:clahan-academy/clahan-academy-helm:ref:refs/heads/main"
Create-FederatedCredential "github-helm-pr" "repo:clahan-academy/clahan-academy-helm:pull_request"
Create-FederatedCredential "github-helm-feature" "repo:clahan-academy/clahan-academy-helm:ref:refs/heads/feature/*"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   SECTION 5: Deployer Identity"
Write-Host "============================================" -ForegroundColor Cyan

$DeployerObjectId = (az ad signed-in-user show --query id -o tsv)
Write-Host "[INFO] Deployer Object ID: $DeployerObjectId" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   SECTION 6: Save Config Outputs"
Write-Host "============================================" -ForegroundColor Cyan

$Lines = @(
    "============================================",
    "BOOTSTRAP OUTPUT - DO NOT COMMIT THIS FILE",
    "============================================",
    "Generated: $((Get-Date).ToString())",
    "",
    "--- Terraform State Backend ---",
    "Resource Group:    rg-clahan-tfstate",
    "Storage Account:   $TfStorageAccount",
    "Container:         tfstate",
    "State Key:         dev/terraform.tfstate",
    "",
    "--- GitHub Actions Service Principal ---",
    "Display Name:      sp-github-clahan-ci",
    "Client ID:         $AppId",
    "SP Object ID:      $SpObjectId",
    "Tenant ID:         $TenantId",
    "Subscription ID:   $SubscriptionId",
    "",
    "--- Deployer ---",
    "Object ID:         $DeployerObjectId",
    "",
    "============================================",
    "COPY THESE TO: terraform/environments/dev/terraform.tfvars",
    "============================================",
    "subscription_id      = `"$SubscriptionId`"",
    "tenant_id            = `"$TenantId`"",
    "github_app_client_id = `"$AppId`"",
    "github_sp_object_id  = `"$SpObjectId`"",
    "deployer_object_id   = `"$DeployerObjectId`"",
    "============================================",
    "",
    "COPY THESE TO: GitHub Repo -> Settings -> Secrets -> Actions",
    "============================================",
    "AZURE_CLIENT_ID        = $AppId",
    "AZURE_TENANT_ID        = $TenantId",
    "AZURE_SUBSCRIPTION_ID  = $SubscriptionId",
    "============================================"
)

$OutputText = $Lines -join "`r`n"
$OutputText | Out-File -FilePath .bootstrap-output.txt -Encoding ascii
Write-Host "[OK] Output saved to .bootstrap-output.txt" -ForegroundColor Green

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "            BOOTSTRAP COMPLETE               " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host "1. Copy values from .bootstrap-output.txt to:" -ForegroundColor Yellow
Write-Host "   terraform/environments/dev/terraform.tfvars" -ForegroundColor Yellow
Write-Host "2. Fill remaining secrets in terraform.tfvars:" -ForegroundColor Yellow
Write-Host "   - db_password (choose a strong password)" -ForegroundColor Yellow
Write-Host "   - smtp_user, smtp_pass, smtp_from" -ForegroundColor Yellow
Write-Host "   - snyk_token, sonar_token" -ForegroundColor Yellow
Write-Host "3. Add AZURE_CLIENT_ID, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID to GitHub Secrets" -ForegroundColor Yellow
Write-Host "4. Update your backend.tf file (line 7) with the generated storage_account_name ($TfStorageAccount)." -ForegroundColor Yellow
Write-Host "5. Commit changes and trigger the terraform-apply workflow on GitHub!" -ForegroundColor Yellow

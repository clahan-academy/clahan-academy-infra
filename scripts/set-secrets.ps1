# clahan-academy-infra/scripts/set-secrets.ps1
# Non-interactive script to set all application secrets in Azure Key Vault

$ErrorActionPreference = "Stop"

# Target Key Vault name
$vaultName = "kv-clahan-prod"

# Verify Azure CLI login
Write-Host "Verifying Azure connection..." -ForegroundColor Cyan
$account = az account show --query name -o tsv 2>$null
if ($null -eq $account) {
    Write-Host "You are not logged in. Please run 'az login' first." -ForegroundColor Red
    exit 1
}

# Key-Value map of all secrets
$secrets = [ordered]@{
    "smtp-host"        = "smtp.gmail.com"
    "smtp-port"        = "465"
    "smtp-user"        = "aiexamplatform123@gmail.com"
    "smtp-pass"        = "zmso iaml jdkh wpxn"
    "smtp-from"        = "aiexamplatform123@gmail.com"
    "sendgrid-api-key" = "SG.placeholder_sendgrid_key"
    "sendgrid-from"    = "noreply@clahanacademy.com"
    "sonar-token"      = "5c7418c03235a4fa41706224d3c075c4e9c425a7"
    "snyk-token"       = "snyk_token_placeholder"
}

Write-Host "Setting all secrets automatically in Key Vault: $vaultName" -ForegroundColor Cyan

foreach ($name in $secrets.Keys) {
    $value = $secrets[$name]
    Write-Host "Updating secret '$name'..." -ForegroundColor Yellow
    $result = az keyvault secret set --vault-name $vaultName --name $name --value $value --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Secret '$name' set successfully." -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to update secret '$name': $result" -ForegroundColor Red
    }
}

Write-Host "`nAll secrets successfully updated in Key Vault!" -ForegroundColor Green

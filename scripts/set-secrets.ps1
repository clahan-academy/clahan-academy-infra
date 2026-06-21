# clahan-academy-infra/scripts/set-secrets.ps1
# Script to manually set application secrets in Azure Key Vault

$ErrorActionPreference = "Stop"

# Default Key Vault name
$defaultVault = "kv-cl06211355"
$vaultName = Read-Host "Enter Azure Key Vault Name [default: $defaultVault]"
if ([string]::IsNullOrWhiteSpace($vaultName)) {
    $vaultName = $defaultVault
}

# Verify Azure CLI login
Write-Host "Verifying Azure connection..." -ForegroundColor Cyan
$account = az account show --query name -o tsv 2>$null
if ($null -eq $account) {
    Write-Host "You are not logged in. Redirecting to az login..." -ForegroundColor Yellow
    az login
} else {
    Write-Host "Connected to Azure subscription: $account" -ForegroundColor Green
}

# List of secrets to set
$secrets = @(
    @{ Name = "sonar-token"; Description = "SonarCloud Token for CI static analysis" },
    @{ Name = "snyk-token"; Description = "Snyk Token for dependency vulnerability scanning" },
    @{ Name = "smtp-pass"; Description = "SMTP relay server password" },
    @{ Name = "smtp-user"; Description = "SMTP relay username" },
    @{ Name = "smtp-from"; Description = "SMTP sender address" },
    @{ Name = "sendgrid-api-key"; Description = "SendGrid API Key (optional)" },
    @{ Name = "sendgrid-from"; Description = "SendGrid sender email (optional)" }
)

Write-Host "`nReady to set secrets in Key Vault: $vaultName" -ForegroundColor Cyan
Write-Host "Press [Enter] to skip a secret if it is already populated or unchanged.`n" -ForegroundColor DarkGray

foreach ($sec in $secrets) {
    $name = $sec.Name
    $desc = $sec.Description
    
    # Prompt securely for sensitive values
    $promptMsg = "Enter value for '$name' ($desc):"
    
    # If it is a token or password, read as secure string
    if ($name -match "token|pass|key") {
        $valSecure = Read-Host $promptMsg -AsSecureString
        $value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($valSecure)
        )
    } else {
        $value = Read-Host $promptMsg
    }
    
    if (![string]::IsNullOrEmpty($value)) {
        Write-Host "Updating secret '$name'..." -ForegroundColor Yellow
        $result = az keyvault secret set --vault-name $vaultName --name $name --value $value --output none 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Secret '$name' updated successfully.`n" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to update secret '$name': $result`n" -ForegroundColor Red
        }
    } else {
        Write-Host "Skipped '$name'.`n" -ForegroundColor Gray
    }
}

Write-Host "Secret configuration complete!" -ForegroundColor Green

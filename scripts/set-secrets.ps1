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

# List of secrets with defaults
$secrets = @(
    @{ Name = "sonar-token"; Description = "SonarCloud Token for CI static analysis"; Default = "" },
    @{ Name = "snyk-token"; Description = "Snyk Token for dependency vulnerability scanning"; Default = "" },
    @{ Name = "smtp-host"; Description = "SMTP relay host"; Default = "smtp.gmail.com" },
    @{ Name = "smtp-port"; Description = "SMTP port"; Default = "465" },
    @{ Name = "smtp-user"; Description = "SMTP username"; Default = "aiexamplatform123@gmail.com" },
    @{ Name = "smtp-pass"; Description = "SMTP password (app password)"; Default = "zmso iaml jdkh wpxn" },
    @{ Name = "smtp-from"; Description = "SMTP sender email"; Default = "aiexamplatform123@gmail.com" },
    @{ Name = "sendgrid-api-key"; Description = "SendGrid API Key"; Default = "" },
    @{ Name = "sendgrid-from"; Description = "SendGrid sender email"; Default = "noreply@clahanacademy.com" }
)

Write-Host "`nReady to set secrets in Key Vault: $vaultName" -ForegroundColor Cyan
Write-Host "Press [Enter] to use the shown default, or type a new value.`n" -ForegroundColor DarkGray

foreach ($sec in $secrets) {
    $name = $sec.Name
    $desc = $sec.Description
    $default = $sec.Default
    
    $promptMsg = "Enter value for '$name' ($desc)"
    if ($default) {
        $promptMsg += " [default: $default]"
    }
    $promptMsg += ":"

    # Read input (securely for passwords if they type a new one, but allow entering default easily)
    if ($name -match "token|pass|key") {
        # Secure prompt for secret inputs
        $valSecure = Read-Host $promptMsg -AsSecureString
        $value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($valSecure)
        )
    } else {
        $value = Read-Host $promptMsg
    }
    
    # If no value entered, use default
    if ([string]::IsNullOrEmpty($value)) {
        $value = $default
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
        Write-Host "Skipped '$name' (no value or default provided).`n" -ForegroundColor Gray
    }
}

Write-Host "Secret configuration complete!" -ForegroundColor Green

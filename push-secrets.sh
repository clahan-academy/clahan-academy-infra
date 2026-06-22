#!/usr/bin/env bash
# script to push application secrets manually to Azure Key Vault
set -euo pipefail

# Default Key Vault name (can be overridden by argument)
KV_NAME="${1:-kv-clahan-prod}"

echo "============================================================"
echo "Pushing Application Secrets to Azure Key Vault: ${KV_NAME}"
echo "============================================================"

# Verify user is logged in
if ! az account show >/dev/null 2>&1; then
    echo "Error: You are not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Function to prompt for secret if not provided
set_kv_secret() {
    local secret_name="$1"
    local description="$2"
    local default_val="${3:-}"
    
    echo -n "Enter value for '${secret_name}' (${description}) [${default_val}]: "
    read -r val
    val="${val:-$default_val}"
    
    if [ -z "$val" ]; then
        echo "Skipping ${secret_name} (empty value)"
        return
    fi
    
    echo "Setting secret '${secret_name}' in Key Vault..."
    az keyvault secret set --vault-name "${KV_NAME}" --name "${secret_name}" --value "${val}" --output none
}

# 1. SMTP configuration
set_kv_secret "smtp-host" "SMTP server host" "smtp.gmail.com"
set_kv_secret "smtp-port" "SMTP server port" "587"
set_kv_secret "smtp-user" "SMTP username/email" "YOUR_GMAIL_USERNAME@gmail.com"
set_kv_secret "smtp-pass" "SMTP password/app password" ""
set_kv_secret "smtp-from" "SMTP sender email" "YOUR_GMAIL_USERNAME@gmail.com"

# 2. SendGrid configuration (Optional)
set_kv_secret "sendgrid-api-key" "SendGrid API key" ""
set_kv_secret "sendgrid-from" "SendGrid sender email" ""

# 3. Security Tokens
set_kv_secret "snyk-token" "Snyk security scanning token" ""
set_kv_secret "sonar-token" "SonarQube analysis token" "5c7418c03235a4fa41706224d3c075c4e9c425a7"

echo "============================================================"
echo "Successfully pushed all secrets to Key Vault: ${KV_NAME}"
echo "============================================================"

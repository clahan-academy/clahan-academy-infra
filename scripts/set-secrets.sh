#!/bin/bash
# clahan-academy-infra/scripts/set-secrets.sh
# Script to manually set application secrets in Azure Key Vault (Bash)

set -e

# Default Key Vault name
DEFAULT_VAULT="kv-cl06211355"
read -p "Enter Azure Key Vault Name [default: $DEFAULT_VAULT]: " VAULT_NAME
VAULT_NAME=${VAULT_NAME:-$DEFAULT_VAULT}

echo "Verifying Azure connection..."
if ! az account show --query name -o tsv > /dev/null 2>&1; then
    echo "You are not logged in. Running az login..."
    az login
fi

echo "Connected to Azure subscription."
echo ""
echo "Ready to set secrets in Key Vault: $VAULT_NAME"
echo "Press [Enter] to skip a secret if it is already populated or unchanged."
echo ""

# Helper function to read input and update secret
update_secret() {
    local name=$1
    local desc=$2
    local is_sensitive=$3
    local value=""

    if [ "$is_sensitive" = "true" ]; then
        # Read sensitive input without echoing characters
        read -s -p "Enter value for '$name' ($desc): " value
        echo ""
    else
        read -p "Enter value for '$name' ($desc): " value
    fi

    if [ -n "$value" ]; then
        echo "Updating secret '$name'..."
        az keyvault secret set --vault-name "$VAULT_NAME" --name "$name" --value "$value" --output none
        echo "✅ Secret '$name' updated successfully."
        echo ""
    else
        echo "Skipped '$name'."
        echo ""
    fi
}

# Prompt for each secret
update_secret "sonar-token" "SonarCloud Token for CI static analysis" "true"
update_secret "snyk-token" "Snyk Token for dependency vulnerability scanning" "true"
update_secret "smtp-pass" "SMTP relay server password" "true"
update_secret "smtp-user" "SMTP relay username" "false"
update_secret "smtp-from" "SMTP sender address" "false"
update_secret "sendgrid-api-key" "SendGrid API Key (optional)" "true"
update_secret "sendgrid-from" "SendGrid sender email (optional)" "false"

echo "Secret configuration complete!"

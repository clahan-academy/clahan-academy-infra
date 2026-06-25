#!/bin/bash
# clahan-academy-infra/scripts/set-secrets.sh
# Non-interactive script to set all application secrets in Azure Key Vault (Bash)

set -e

# Target Key Vault name
VAULT_NAME="kv-clahan-prod"

echo "Verifying Azure connection..."
if ! az account show --query name -o tsv > /dev/null 2>&1; then
    echo "You are not logged in. Please run 'az login' first."
    exit 1
fi

echo "Setting all secrets automatically in Key Vault: $VAULT_NAME"
echo ""

update_secret() {
    local name=$1
    local value=$2

    echo "Updating secret '$name'..."
    az keyvault secret set --vault-name "$VAULT_NAME" --name "$name" --value "$value" --output none
    echo "✅ Secret '$name' set successfully."
    echo ""
}

update_secret "smtp-host" "smtp.gmail.com"
update_secret "smtp-port" "465"
update_secret "smtp-user" "aiexamplatform123@gmail.com"
update_secret "smtp-pass" "zmso iaml jdkh wpxn"
update_secret "smtp-from" "aiexamplatform123@gmail.com"
update_secret "sendgrid-api-key" "SG.placeholder_sendgrid_key"
update_secret "sendgrid-from" "noreply@clahanacademy.com"
update_secret "sonar-token" "5c7418c03235a4fa41706224d3c075c4e9c425a7"
update_secret "snyk-token" "snyk_token_placeholder"

echo "All secrets successfully updated in Key Vault!"

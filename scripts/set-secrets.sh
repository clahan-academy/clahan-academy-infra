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
echo "Press [Enter] to use the shown default, or type a new value."
echo ""

# Helper function to read input and update secret
update_secret() {
    local name=$1
    local desc=$2
    local is_sensitive=$3
    local default_val=$4
    local value=""

    local prompt_msg="Enter value for '$name' ($desc)"
    if [ -n "$default_val" ]; then
        prompt_msg="$prompt_msg [default: $default_val]"
    fi
    prompt_msg="$prompt_msg: "

    if [ "$is_sensitive" = "true" ]; then
        read -s -p "$prompt_msg" value
        echo ""
    else
        read -p "$prompt_msg" value
    fi

    # Use default if input is empty
    value=${value:-$default_val}

    if [ -n "$value" ]; then
        echo "Updating secret '$name'..."
        az keyvault secret set --vault-name "$VAULT_NAME" --name "$name" --value "$value" --output none
        echo "✅ Secret '$name' updated successfully."
        echo ""
    else
        echo "Skipped '$name' (no value or default provided)."
        echo ""
    fi
}

# Prompt for each secret
update_secret "sonar-token" "SonarCloud Token for CI static analysis" "true" ""
update_secret "snyk-token" "Snyk Token for dependency vulnerability scanning" "true" ""
update_secret "smtp-host" "SMTP relay host" "false" "smtp.gmail.com"
update_secret "smtp-port" "SMTP port" "false" "465"
update_secret "smtp-user" "SMTP username" "false" "aiexamplatform123@gmail.com"
update_secret "smtp-pass" "SMTP password (app password)" "true" "zmso iaml jdkh wpxn"
update_secret "smtp-from" "SMTP sender email" "false" "aiexamplatform123@gmail.com"
update_secret "sendgrid-api-key" "SendGrid API Key" "true" ""
update_secret "sendgrid-from" "SendGrid sender email" "false" "noreply@clahanacademy.com"

echo "Secret configuration complete!"

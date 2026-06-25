#!/bin/bash
# push-secrets.sh
# Fetch secrets from Azure Key Vault and create Kubernetes Secrets manually.
# Usage: ./push-secrets.sh <vault-name> <namespace>

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <vault-name> <namespace>"
    exit 1
fi

VAULT_NAME="$1"
NAMESPACE="$2"

echo "Fetching secrets from Key Vault: $VAULT_NAME and pushing to namespace: $NAMESPACE..."

# Helper to fetch a secret and create/update a Kubernetes secret
# Usage: create_k8s_secret <secret-name> <key1> <kv-secret1> ...
create_k8s_secret() {
    local secret_name="$1"
    shift
    
    echo "Processing Kubernetes Secret: $secret_name"
    
    # Build the kubectl command dynamically
    local cmd="kubectl create secret generic $secret_name -n $NAMESPACE"
    
    while [ "$#" -gt 0 ]; do
        local key="$1"
        local kv_secret_name="$2"
        shift 2
        
        echo "  Fetching secret $kv_secret_name for key $key..."
        local value=$(az keyvault secret show --vault-name "$VAULT_NAME" --name "$kv_secret_name" --query value -o tsv 2>/dev/null || echo "")
        
        if [ -z "$value" ]; then
            echo "  [WARNING] Secret '$kv_secret_name' not found in Key Vault or is empty."
            value="dummy-value-placeholder"
        fi
        
        # Escape value for kubectl if needed
        cmd="$cmd --from-literal=$key='$value'"
    done
    
    # Delete existing secret if it exists
    kubectl delete secret "$secret_name" -n "$NAMESPACE" --ignore-not-found
    
    # Run the command to create the secret
    eval "$cmd"
    echo "  Successfully created/updated secret: $secret_name"
}

create_k8s_secret "clahan-admin-secrets" "PORT" "admin-port" "DATABASE_URL" "db-connection-string" "REDIS_URL" "redis-connection-string" "JWT_ACCESS_SECRET" "jwt-access-secret" "RATE_LIMIT_MAX" "rate-limit-max"

create_k8s_secret "clahan-ai-secrets" "PORT" "ai-port" "OLLAMA_URL" "ollama-url"

create_k8s_secret "clahan-auth-secrets" "PORT" "auth-port" "DATABASE_URL" "db-connection-string" "REDIS_URL" "redis-connection-string" "JWT_ACCESS_SECRET" "jwt-access-secret" "JWT_REFRESH_SECRET" "jwt-refresh-secret" "RATE_LIMIT_MAX" "rate-limit-max"

create_k8s_secret "clahan-exam-secrets" "PORT" "exam-port" "DATABASE_URL" "db-connection-string" "REDIS_URL" "redis-connection-string" "JWT_ACCESS_SECRET" "jwt-access-secret" "AI_SERVICE_URL" "ai-service-url" "JUDGE0_URL" "judge0-url" "RATE_LIMIT_MAX" "rate-limit-max" "JUDGE0_DB_CONNECTION_STRING" "judge0-db-connection-string"

create_k8s_secret "clahan-frontend-secrets" "PORT" "frontend-port"

create_k8s_secret "clahan-notification-secrets" "PORT" "notification-port" "REDIS_URL" "redis-connection-string" "SMTP_HOST" "smtp-host" "SMTP_PORT" "smtp-port" "SMTP_USER" "smtp-user" "SMTP_PASS" "smtp-pass" "SMTP_FROM" "smtp-from" "FRONTEND_URL" "frontend-url" "SENDGRID_API_KEY" "sendgrid-api-key" "SENDGRID_FROM" "sendgrid-from"

create_k8s_secret "clahan-proctoring-secrets" "PORT" "proctoring-port" "DATABASE_URL" "db-connection-string" "REDIS_URL" "redis-connection-string" "JWT_ACCESS_SECRET" "jwt-access-secret" "AI_SERVICE_URL" "ai-service-url" "TAB_SWITCH_LIMIT" "tab-switch-limit" "MOBILE_PHONE_LIMIT" "mobile-phone-limit" "BOOK_LIMIT" "book-limit" "MULTIPLE_FACES_LIMIT" "multiple-faces-limit" "NO_FACE_TIMEOUT_MS" "no-face-timeout-ms" "FULLSCREEN_EXIT_LIMIT" "fullscreen-exit-limit"

create_k8s_secret "clahan-student-secrets" "PORT" "student-port" "DATABASE_URL" "db-connection-string" "JWT_ACCESS_SECRET" "jwt-access-secret" "RATE_LIMIT_MAX" "rate-limit-max"

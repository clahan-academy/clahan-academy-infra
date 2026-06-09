#!/usr/bin/env bash
# =====================================================================
# Clahan-Academy Manual DR Failover Script
# Promotes the SEA replica PostgreSQL and scales up standby Container Apps
# =====================================================================
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment> (dev|staging|prod)"
  exit 1
fi

ENV=$1

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  echo "Error: Invalid environment '$ENV'. Must be dev, staging, or prod."
  exit 1
fi

RG_NAME="rg-clahan-$ENV-sea-dr"
DB_NAME="pg-clahan-$ENV-sea-replica"

echo "==> Initiating manual failover for environment: $ENV..."

# Step 1: Promote PostgreSQL Flexible Server Replica
echo "==> Step 1: Promoting PostgreSQL Read Replica ($DB_NAME) in resource group $RG_NAME..."
az postgres flexible-server replica promote \
  --name "$DB_NAME" \
  --resource-group "$RG_NAME" \
  --yes

# Step 2: Scale up Standby Container Apps
echo "==> Step 2: Scaling up Southeast Asia Container Apps from 0 to 1 min replicas..."
APPS=(
  "frontend-service"
  "auth-service"
  "admin-service"
  "student-service"
  "exam-service"
  "notification-service"
  "proctoring-service"
  "ai-service"
  "yolo-v8"
  "ocr"
  "ollama"
)

for app in "${APPS[@]}"; do
  APP_NAME="ca-clahan-$ENV-sea-$app"
  echo "Scaling up app: $APP_NAME..."
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RG_NAME" \
    --min-replicas 1
done

echo "==> Manual failover completed successfully! Southeast Asia is now the Active region."

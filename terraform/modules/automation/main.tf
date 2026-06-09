# Automation Account
resource "azurerm_automation_account" "aa" {
  name                = var.automation_account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Role Assignment: Contributor on Primary Resource Group
resource "azurerm_role_assignment" "aa_primary_contrib" {
  scope                = var.primary_rg_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.aa.identity[0].principal_id
}

# Role Assignment: Contributor on DR Resource Group
resource "azurerm_role_assignment" "aa_dr_contrib" {
  count                = var.dr_rg_id != "" && var.dr_rg_id != null ? 1 : 0
  scope                = var.dr_rg_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.aa.identity[0].principal_id
}

# PowerShell Runbook: DR Failover Orchestration
resource "azurerm_automation_runbook" "failover" {
  name                    = "rb-clahan-failover"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Connects with Managed Identity, promotes PG read replica, and scales up DR container apps."
  runbook_type            = "PowerShell"

  content = <<EXPRESSION
# Connect to Azure using System-Assigned Managed Identity
Write-Output "Connecting to Azure via Managed Identity..."
Disable-AzContextAutosave -Scope Process
$AzureContext = (Connect-AzAccount -Identity).context

# Promote PostgreSQL Read Replica
Write-Output "Promoting PostgreSQL Read Replica..."
az postgres flexible-server replica promote --name pg-clahan-${var.environment}-sea-replica --resource-group rg-clahan-${var.environment}-sea-dr --yes

# Scale up DR Container Apps (updating min_replicas from 0 to 1)
Write-Output "Scaling up Standby DR Container Apps..."
$containerApps = @(
    "frontend-service", "auth-service", "admin-service", "student-service", 
    "exam-service", "notification-service", "proctoring-service", "ai-service", 
    "yolo-v8", "ocr", "ollama"
)
foreach ($app in $containerApps) {
    Write-Output "Scaling app: ca-clahan-${var.environment}-sea-$app"
    az containerapp update --name "ca-clahan-${var.environment}-sea-$app" --resource-group rg-clahan-${var.environment}-sea-dr --min-replicas 1
}

Write-Output "DR Failover Completed Successfully."
EXPRESSION
}

# PowerShell Runbook: DR Failback Orchestration
resource "azurerm_automation_runbook" "failback" {
  name                    = "rb-clahan-failback"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Connects with Managed Identity, and scales down DR container apps back to standby."
  runbook_type            = "PowerShell"

  content = <<EXPRESSION
# Connect to Azure using System-Assigned Managed Identity
Write-Output "Connecting to Azure via Managed Identity..."
Disable-AzContextAutosave -Scope Process
$AzureContext = (Connect-AzAccount -Identity).context

# Scale down DR Container Apps (updating min_replicas from 1 to 0)
Write-Output "Scaling down DR Container Apps..."
$containerApps = @(
    "frontend-service", "auth-service", "admin-service", "student-service", 
    "exam-service", "notification-service", "proctoring-service", "ai-service", 
    "yolo-v8", "ocr", "ollama"
)
foreach ($app in $containerApps) {
    Write-Output "Scaling down app: ca-clahan-${var.environment}-sea-$app"
    az containerapp update --name "ca-clahan-${var.environment}-sea-$app" --resource-group rg-clahan-${var.environment}-sea-dr --min-replicas 0
}

Write-Output "DR Failback Completed."
EXPRESSION
}

# Webhook for Failover Runbook
# Triggers the rb-clahan-failover runbook when hit by monitoring alert.
resource "azurerm_automation_webhook" "failover" {
  name                    = "webhook-failover"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.aa.name
  expiry_time             = "2030-01-01T00:00:00Z"
  enabled                 = true
  runbook_name            = azurerm_automation_runbook.failover.name
}

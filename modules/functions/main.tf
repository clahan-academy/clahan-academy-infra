# terraform/modules/functions/main.tf

locals {
  tags = merge(var.tags, {
    module = "functions"
  })
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Archive the Function App code
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/app_code"
  output_path = "${path.module}/function_app.zip"
}

# Consumption plan - serverless, pay per execution, zero cost at rest
resource "azurerm_service_plan" "main" {
  name                = "asp-clahan-functions"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.tags
}

# ResourceHealthMonitor / StopResources function app
resource "azurerm_linux_function_app" "main" {
  name                       = "func-clahan-academy"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_key
  service_plan_id            = azurerm_service_plan.main.id
  https_only                 = true

  zip_deploy_file = data.archive_file.function_zip.output_path

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "20"
    }
    application_insights_key               = var.app_insights_instrumentation_key
    application_insights_connection_string = var.app_insights_connection_string
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "node"
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    "WEBSITE_TIME_ZONE"                     = "India Standard Time"
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = var.app_insights_instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_connection_string
    
    # Target Resource configurations
    "AZURE_SUBSCRIPTION_ID" = var.subscription_id
    "RESOURCE_GROUP"        = var.resource_group_name
    "AKS_CLUSTER_NAME"      = "aks-clahan-academy"
    "VM_NAME"               = "vm-clahan-jump"

    # Key Vault secret references for SMTP alerts
    "DATABASE_URL"          = "@Microsoft.KeyVault(VaultName=${split("/", var.key_vault_id)[8]};SecretName=db-connection-string)"
    "SMTP_HOST"             = "@Microsoft.KeyVault(VaultName=${split("/", var.key_vault_id)[8]};SecretName=smtp-host)"
    "SMTP_PORT"             = "@Microsoft.KeyVault(VaultName=${split("/", var.key_vault_id)[8]};SecretName=smtp-port)"
    "SMTP_USER"             = "@Microsoft.KeyVault(VaultName=${split("/", var.key_vault_id)[8]};SecretName=smtp-user)"
    "SMTP_PASS"             = "@Microsoft.KeyVault(VaultName=${split("/", var.key_vault_id)[8]};SecretName=smtp-pass)"
    "ADMIN_EMAIL"           = var.admin_email
  }

  tags = local.tags
}

# Allow Function App to read secrets from Key Vault
resource "azurerm_role_assignment" "function_keyvault_reader" {
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_linux_function_app.main.identity[0].principal_id
  scope                            = var.key_vault_id
  skip_service_principal_aad_check = true

  lifecycle {
    ignore_changes = all
  }
}

# Allow Function App to stop resources in the Resource Group
resource "azurerm_role_assignment" "function_rg_contributor" {
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_linux_function_app.main.identity[0].principal_id
  scope                            = data.azurerm_resource_group.main.id
  skip_service_principal_aad_check = true
}

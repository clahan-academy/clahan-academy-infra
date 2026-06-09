# Storage Account for Function App runtime
resource "azurerm_storage_account" "st" {
  name                     = "stcl${substr(var.environment, 0, 4)}${var.region_short}${var.random_suffix}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# Service Plan (Consumption Plan - Y1)
resource "azurerm_service_plan" "plan" {
  name                = "plan-clahan-${var.environment}-${var.region_short}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = var.tags
}

# Linux Function App (Python 3.11)
resource "azurerm_linux_function_app" "func" {
  name                       = "func-clahan-${var.environment}-${var.region_short}-cleanup"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  storage_account_name       = azurerm_storage_account.st.name
  storage_account_access_key = azurerm_storage_account.st.primary_access_key
  service_plan_id            = azurerm_service_plan.plan.id

  virtual_network_subnet_id = var.subnet_id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    vnet_route_all_enabled = true
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "DATABASE_URL"                   = "@Microsoft.KeyVault(SecretUri=${var.postgres_connection_string_secret_id})"
    "REGION_FLAG"                    = var.region_short
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
  }

  tags = var.tags
}

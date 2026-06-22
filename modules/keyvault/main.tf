# terraform/modules/keyvault/main.tf
# Azure Key Vault - central secret store for all application secrets

locals {
  tags = merge(var.tags, {
    module = "keyvault"
  })
}

# Key Vault with RBAC authorization
resource "azurerm_key_vault" "main" {
  name                          = var.key_vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = "standard"
  tenant_id                     = var.tenant_id
  enable_rbac_authorization     = true
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
    ip_rules       = []
  }

  tags = local.tags
}

# Deployer gets Secrets Officer (deployer is a User not SP)
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  name                 = uuidv5("dns", "${var.deployer_object_id}-kv-admin-${azurerm_key_vault.main.name}")
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.deployer_object_id
  scope                = azurerm_key_vault.main.id
}

# GitHub Actions gets Secrets User
resource "azurerm_role_assignment" "github_secrets_user" {
  name                             = uuidv5("dns", "${var.github_sp_object_id}-kv-user-${azurerm_key_vault.main.name}")
  role_definition_name             = "Key Vault Administrator"
  principal_id                     = var.github_sp_object_id
  scope                            = azurerm_key_vault.main.id
  skip_service_principal_aad_check = true
}
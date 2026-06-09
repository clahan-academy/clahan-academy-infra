data "azurerm_client_config" "current" {}

# Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "kv-clahan-${var.environment}-${var.region_short}-${var.random_suffix}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  rbac_authorization_enabled  = true
  public_network_access_enabled = true

  tags = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-kv-clahan-${var.environment}-${var.region_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-kv-clahan-${var.environment}-${var.region_short}"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "dns-group-kv"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

# Grant the Deploying Identity Key Vault Secrets Officer role
# This is required to write secrets into the Key Vault during the Terraform apply
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Create Key Vault Secrets
resource "azurerm_key_vault_secret" "secrets" {
  for_each     = var.secrets
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.kv.id

  # Ensure the role assignment is active before attempting to write secrets
  depends_on = [
    azurerm_role_assignment.deployer_secrets_officer,
    azurerm_private_endpoint.kv_pe
  ]
}

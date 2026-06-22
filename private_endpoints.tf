# terraform/private_endpoints.tf
# Configures Private Endpoints for Key Vault, ACR, Redis, and Storage Account

# 1. Key Vault Private Endpoint
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-keyvault"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  subnet_id           = module.networking.subnet_privateendpoints_id

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = module.keyvault.key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-keyvault"
    private_dns_zone_ids = [module.networking.private_dns_zone_ids["keyvault"]]
  }

  tags = local.tags
}

# 2. Azure Container Registry (ACR) Private Endpoint
resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  subnet_id           = module.networking.subnet_privateendpoints_id

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = module.acr.acr_id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-acr"
    private_dns_zone_ids = [module.networking.private_dns_zone_ids["acr"]]
  }

  tags = local.tags
}

# 4. Storage Account Private Endpoint (Blob)
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-storage-blob"
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  subnet_id           = module.networking.subnet_privateendpoints_id

  private_service_connection {
    name                           = "psc-storage-blob"
    private_connection_resource_id = module.storage.storage_account_id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-storage-blob"
    private_dns_zone_ids = [module.networking.private_dns_zone_ids["blob"]]
  }

  tags = local.tags
}

locals {
  # Map legacy Redis Cache SKUs to the new Azure Managed Redis SKUs
  # Balanced_B1 corresponds to standard 1GB cache.
  # Balanced_B3 corresponds to standard 3GB cache.
  managed_sku = var.sku_name == "Basic" ? "Balanced_B1" : (var.capacity >= 2 ? "Balanced_B3" : "Balanced_B1")
}

resource "azurerm_managed_redis" "redis" {
  name                          = var.redis_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = local.managed_sku
  public_network_access         = "Disabled"

  default_database {
    access_keys_authentication_enabled = true
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "redis_pe" {
  name                = "pe-${var.redis_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-${var.redis_name}"
    private_connection_resource_id = azurerm_managed_redis.redis.id
    is_manual_connection           = false
    subresource_names              = ["redisEnterprise"]
  }

  private_dns_zone_group {
    name                 = "dns-group-redis"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

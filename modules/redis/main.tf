# terraform/modules/redis/main.tf
# Azure Cache for Redis (Standard) - used for BullMQ job queue and session caching

locals {
  tags = merge(var.tags, {
    module = "redis"
  })

  redis_key               = var.environment == "prod" ? azurerm_redis_cache.main[0].primary_access_key : "dummy_dev_key"
  redis_host              = var.environment == "prod" ? azurerm_redis_cache.main[0].hostname : "redis"
  redis_connection_string = var.environment == "prod" ? "rediss://:${local.redis_key}@${local.redis_host}:6380" : "redis://redis:6379"
}

# Generate a unique suffix for the Redis name
resource "random_string" "redis_suffix" {
  count   = var.environment == "prod" ? 1 : 0
  length  = 6
  special = false
  upper   = false
  numeric = true
  keepers = {
    # Increment this value to force-rotate the Redis name if Azure has deletion lag/locks
    rotation = "3"
  }
}

# Provision standard Azure Cache for Redis
resource "azurerm_redis_cache" "main" {
  count                = var.environment == "prod" ? 1 : 0
  name                 = "redis-clahan-prod-${random_string.redis_suffix[0].result}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  capacity             = var.redis_capacity
  family               = "C"
  sku_name             = "Standard"
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"

  redis_configuration {
    authentication_enabled          = true
    maxmemory_policy                = "allkeys-lru"
    maxmemory_reserved              = 50
    maxfragmentationmemory_reserved = 50
  }

  tags = local.tags
}

# Save connection details to Key Vault
resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "redis-connection-string"
  value        = local.redis_connection_string
  key_vault_id = var.key_vault_id
  content_type = "text/plain"
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "redis_primary_key" {
  name         = "redis-primary-key"
  value        = local.redis_key
  key_vault_id = var.key_vault_id
  content_type = "text/plain"
  tags         = local.tags
}
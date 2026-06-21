# terraform/modules/redis/main.tf
# Azure Managed Redis (Enterprise) - used for BullMQ job queue and session caching

terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

locals {
  tags = merge(var.tags, {
    module = "redis"
  })

  redis_key               = try(jsondecode(data.azapi_resource_action.redis_keys.output).primaryKey, "dummy_key")
  redis_host              = try(jsondecode(azapi_resource.redis.output).properties.hostName, "dummy_host")
  redis_connection_string = "rediss://:${local.redis_key}@${local.redis_host}:10000"
}

# Generate a unique suffix for the Redis Enterprise name
resource "random_string" "redis_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Provision Redis Enterprise cluster
resource "azapi_resource" "redis" {
  type                      = "Microsoft.Cache/redisEnterprise@2024-10-01"
  schema_validation_enabled = false
  name                      = "redis-clahan-${random_string.redis_suffix.result}"
  parent_id                 = var.resource_group_id
  location                  = var.location

  body = {
    sku = {
      name = "Balanced_B0"
    }
    properties = {
      minimumTlsVersion = "1.2"
    }
  }

  tags = local.tags
}

# Provision default database under the cluster
resource "azapi_resource" "redis_db" {
  type                      = "Microsoft.Cache/redisEnterprise/databases@2024-10-01"
  schema_validation_enabled = false
  name                      = "default"
  parent_id                 = azapi_resource.redis.id

  body = {
    properties = {
      clientProtocol   = "Encrypted"
      clusteringPolicy = "OSSCluster"
      evictionPolicy   = "VolatileLRU"
      port             = 10000
    }
  }
}

# Fetch access keys for connection string
data "azapi_resource_action" "redis_keys" {
  type        = "Microsoft.Cache/redisEnterprise/databases@2024-10-01"
  resource_id = azapi_resource.redis_db.id
  action      = "listKeys"
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
# terraform/modules/redis/main.tf
# Azure Managed Redis (Enterprise) - used for BullMQ job queue and session caching

locals {
  tags = merge(var.tags, {
    module = "redis"
  })

  redis_key               = var.environment == "prod" ? azurerm_redis_enterprise_database.redis_db[0].primary_access_key : "dummy_dev_key"
  redis_host              = var.environment == "prod" ? azurerm_redis_enterprise_cluster.redis[0].hostname : "redis"
  redis_connection_string = var.environment == "prod" ? "rediss://:${local.redis_key}@${local.redis_host}:10000" : "redis://redis:6379"
}

# Generate a unique suffix for the Redis Enterprise name
resource "random_string" "redis_suffix" {
  count   = var.environment == "prod" ? 1 : 0
  length  = 6
  special = false
  upper   = false
  numeric = true
  keepers = {
    # Increment this value to force-rotate the Redis name if Azure has deletion lag/locks
    rotation = "2"
  }
}

# Provision Redis Enterprise cluster (Azure Managed Redis) using native azurerm provider
resource "azurerm_redis_enterprise_cluster" "redis" {
  count               = var.environment == "prod" ? 1 : 0
  name                = "redis-clahan-prod-${random_string.redis_suffix[0].result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Enterprise_E5-2"
  tags                = local.tags
}

# Provision default database under the cluster
resource "azurerm_redis_enterprise_database" "redis_db" {
  count             = var.environment == "prod" ? 1 : 0
  name              = "default"
  cluster_id        = azurerm_redis_enterprise_cluster.redis[0].id
  client_protocol   = "Encrypted"
  clustering_policy = "OSSCluster"
  eviction_policy   = "VolatileLRU"
  port              = 10000
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
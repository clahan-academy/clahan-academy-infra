# terraform/modules/redis/main.tf
# Redis configuration for BullMQ job queue and session caching
# NOTE: Azure Cache for Redis has been retired by Microsoft.
# Using in-cluster Redis (deployed via Helm) for all environments.

locals {
  tags = merge(var.tags, {
    module = "redis"
  })

  # In-cluster Redis connection (deployed as a pod in AKS via Helm chart)
  redis_key               = "not-applicable"
  redis_host              = "redis"
  redis_connection_string = "redis://redis:6379"
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
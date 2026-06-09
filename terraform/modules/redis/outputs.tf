output "redis_id" {
  value       = azurerm_managed_redis.redis.id
  description = "The ID of the Redis Cache."
}

output "redis_name" {
  value       = azurerm_managed_redis.redis.name
  description = "The name of the Redis Cache."
}

output "hostname" {
  value       = azurerm_managed_redis.redis.hostname
  description = "The hostname of the Redis Cache."
}

output "ssl_port" {
  value       = azurerm_managed_redis.redis.default_database[0].port
  description = "The SSL port of the Redis Cache."
}

output "primary_access_key" {
  value       = azurerm_managed_redis.redis.default_database[0].primary_access_key
  sensitive   = true
  description = "The primary access key for the Redis Cache."
}

output "connection_string" {
  value       = "rediss://default:${azurerm_managed_redis.redis.default_database[0].primary_access_key}@${azurerm_managed_redis.redis.hostname}:${azurerm_managed_redis.redis.default_database[0].port}"
  sensitive   = true
  description = "The connection string URI for the Redis Cache."
}

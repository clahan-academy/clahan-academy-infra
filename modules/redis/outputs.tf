# terraform/modules/redis/outputs.tf

output "redis_id" {
  description = "Resource ID of the Redis cache"
  value       = var.environment == "prod" ? azapi_resource.redis[0].id : null
}

output "redis_hostname" {
  description = "Hostname of the Redis cache"
  value       = local.redis_host
}

output "redis_ssl_port" {
  description = "SSL port of the Redis cache"
  value       = 10000
}

output "redis_primary_key" {
  description = "Primary access key for Redis"
  value       = local.redis_key
  sensitive   = true
}

output "redis_connection_string" {
  description = "Full SSL connection string for Redis"
  value       = local.redis_connection_string
  sensitive   = true
}

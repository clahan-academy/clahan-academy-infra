# terraform/modules/redis/outputs.tf

output "redis_id" {
  description = "Resource ID of the Redis cache (null - using in-cluster Redis)"
  value       = null
}

output "redis_hostname" {
  description = "Hostname of the Redis instance"
  value       = local.redis_host
}

output "redis_ssl_port" {
  description = "SSL port of the Redis cache"
  value       = 6379
}

output "redis_primary_key" {
  description = "Primary access key for Redis"
  value       = local.redis_key
  sensitive   = true
}

output "redis_connection_string" {
  description = "Full connection string for Redis"
  value       = local.redis_connection_string
  sensitive   = true
}

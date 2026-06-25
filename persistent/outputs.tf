# persistent/outputs.tf
output "environment" {
  value = var.environment
}

output "resource_group_name" {
  value = module.networking.resource_group_name
}

output "resource_group_id" {
  value = module.networking.resource_group_id
}

output "subnet_aks_id" {
  value = module.networking.subnet_aks_id
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "subnet_mgmt_id" {
  value = module.networking.subnet_mgmt_id
}

output "subnet_appgw_id" {
  value = module.networking.subnet_appgw_id
}

output "subnet_privateendpoints_id" {
  value = module.networking.subnet_privateendpoints_id
}

output "private_dns_zone_ids" {
  value = module.networking.private_dns_zone_ids
}

output "log_analytics_workspace_id" {
  value = module.monitoring.log_analytics_workspace_id
}

output "app_insights_name" {
  value = module.monitoring.app_insights_name
}

output "acr_id" {
  value = module.acr.acr_id
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "key_vault_id" {
  value = module.keyvault.key_vault_id
}

output "key_vault_name" {
  value = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

output "storage_account_id" {
  value = module.storage.storage_account_id
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "storage_primary_access_key" {
  value     = module.storage.primary_access_key
  sensitive = true
}

output "app_insights_instrumentation_key" {
  value     = module.monitoring.app_insights_instrumentation_key
  sensitive = true
}

output "app_insights_connection_string" {
  value     = module.monitoring.app_insights_connection_string
  sensitive = true
}

output "postgres_fqdn" {
  value = module.postgres.server_fqdn
}

output "postgres_admin_password" {
  value     = module.postgres.admin_password
  sensitive = true
}

output "postgres_app_connection_string" {
  value     = module.postgres.app_connection_string
  sensitive = true
}

output "postgres_judge0_connection_string" {
  value     = module.postgres.judge0_connection_string
  sensitive = true
}

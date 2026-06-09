output "frontdoor_url" {
  value       = var.enable_dr ? module.frontdoor[0].frontdoor_endpoint_url : "Front Door disabled (DR is disabled)"
  description = "The main public entrypoint URL of the Clahan-Academy exam platform."
}

output "frontdoor_fqdn" {
  value       = var.enable_dr ? module.frontdoor[0].frontdoor_endpoint_fqdn : "Front Door disabled (DR is disabled)"
  description = "The FQDN of the Front Door endpoint."
}

output "primary_appgw_ip" {
  value       = module.appgateway_india.public_ip
  description = "The public IP address of the Primary (Central India) Application Gateway."
}

output "primary_appgw_fqdn" {
  value       = module.appgateway_india.public_fqdn
  description = "The public FQDN of the Primary Application Gateway."
}

output "dr_appgw_ip" {
  value       = var.enable_dr ? module.appgateway_sea[0].public_ip : "DR disabled"
  description = "The public IP address of the DR (Southeast Asia) Application Gateway."
}

output "dr_appgw_fqdn" {
  value       = var.enable_dr ? module.appgateway_sea[0].public_fqdn : "DR disabled"
  description = "The public FQDN of the DR Application Gateway."
}

output "primary_postgres_fqdn" {
  value       = module.postgres_india.fqdn
  sensitive   = true
  description = "The internal FQDN of the Primary PostgreSQL server."
}

output "dr_postgres_fqdn" {
  value       = var.enable_dr ? module.postgres_sea[0].fqdn : "DR disabled"
  sensitive   = true
  description = "The internal FQDN of the Standby/DR PostgreSQL server replica."
}

output "primary_kv_uri" {
  value       = module.kv_india.key_vault_uri
  description = "The URI of the Primary region Key Vault."
}

output "dr_kv_uri" {
  value       = var.enable_dr ? module.kv_sea[0].key_vault_uri : "DR disabled"
  description = "The URI of the DR region Key Vault."
}

output "container_apps_environment_id_primary" {
  value       = module.container_apps_india.container_apps_env_id
  description = "The resource ID of the Primary Container Apps Environment."
}

output "automation_account_name" {
  value       = module.automation.automation_account_name
  description = "The name of the shared global Automation Account."
}

output "failover_webhook_uri" {
  value       = module.automation.webhook_failover_uri
  description = "The Webhook service URI that triggers the failover runbook."
  sensitive   = true
}

output "log_analytics_workspace_name" {
  value       = azurerm_log_analytics_workspace.law.name
  description = "The name of the shared Log Analytics Workspace."
}

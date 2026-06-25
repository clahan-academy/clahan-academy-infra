# transient/outputs.tf
output "environment" {
  value = var.environment
}

output "resource_group_name" {
  value = data.terraform_remote_state.persistent.outputs.resource_group_name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_cluster_endpoint" {
  value = module.aks.cluster_private_fqdn
}

output "aks_get_credentials_command" {
  value = "az aks get-credentials --resource-group ${data.terraform_remote_state.persistent.outputs.resource_group_name} --name ${module.aks.cluster_name}"
}

output "acr_login_server" {
  value = data.terraform_remote_state.persistent.outputs.acr_login_server
}

output "key_vault_uri" {
  value = data.terraform_remote_state.persistent.outputs.key_vault_uri
}

output "key_vault_name" {
  value = data.terraform_remote_state.persistent.outputs.key_vault_name
}

output "postgres_fqdn" {
  value = data.terraform_remote_state.persistent.outputs.postgres_fqdn
}

output "redis_hostname" {
  value = "redis.clahan-${var.environment}.svc.cluster.local"
}

output "jump_vm_name" {
  value = try(module.jumpvm[0].vm_name, "disabled")
}

output "jump_vm_private_ip" {
  value = try(module.jumpvm[0].vm_private_ip, "disabled")
}

output "application_url" {
  value = "https://clahaanacademy.online"
}

output "identity_client_ids" {
  value = module.identity.identity_client_ids
}

output "oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "postgres_admin_password" {
  value     = data.terraform_remote_state.persistent.outputs.postgres_admin_password
  sensitive = true
}

output "postgres_app_connection_string" {
  value     = data.terraform_remote_state.persistent.outputs.postgres_app_connection_string
  sensitive = true
}

output "postgres_judge0_connection_string" {
  value     = data.terraform_remote_state.persistent.outputs.postgres_judge0_connection_string
  sensitive = true
}

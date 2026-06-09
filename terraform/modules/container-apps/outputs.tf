output "container_apps_env_id" {
  value = azurerm_container_app_environment.env.id
}

output "container_apps_env_default_domain" {
  value = azurerm_container_app_environment.env.default_domain
}

output "container_app_fqdns" {
  value = { for k, v in azurerm_container_app.app : k => v.ingress[0].fqdn }
}


output "container_app_identities" {
  value = { for k, v in azurerm_container_app.app : k => v.identity[0].principal_id }
}

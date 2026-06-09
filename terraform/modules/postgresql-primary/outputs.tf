output "server_id" {
  value = azurerm_postgresql_flexible_server.primary.id
}

output "server_name" {
  value = azurerm_postgresql_flexible_server.primary.name
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.primary.fqdn
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  value     = var.admin_password
  sensitive = true
}

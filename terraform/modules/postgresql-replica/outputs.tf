output "server_id" {
  value = azurerm_postgresql_flexible_server.replica.id
}

output "server_name" {
  value = azurerm_postgresql_flexible_server.replica.name
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.replica.fqdn
}

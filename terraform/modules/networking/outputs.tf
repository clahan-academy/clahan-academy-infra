output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "snet_appgw_id" {
  value = azurerm_subnet.snet_appgw.id
}

output "snet_containerapp_id" {
  value = azurerm_subnet.snet_containerapp.id
}

output "snet_data_id" {
  value = azurerm_subnet.snet_data.id
}

output "snet_function_id" {
  value = azurerm_subnet.snet_function.id
}

output "dns_zone_postgres_id" {
  value = azurerm_private_dns_zone.postgres.id
}

output "dns_zone_postgres_name" {
  value = azurerm_private_dns_zone.postgres.name
}

output "dns_zone_redis_id" {
  value = azurerm_private_dns_zone.redis.id
}

output "dns_zone_redis_name" {
  value = azurerm_private_dns_zone.redis.name
}

output "dns_zone_vault_id" {
  value = azurerm_private_dns_zone.vault.id
}

output "dns_zone_vault_name" {
  value = azurerm_private_dns_zone.vault.name
}

output "dns_zone_servicebus_id" {
  value = azurerm_private_dns_zone.servicebus.id
}

output "dns_zone_servicebus_name" {
  value = azurerm_private_dns_zone.servicebus.name
}

output "appgw_id" {
  value = azurerm_application_gateway.appgw.id
}

output "public_ip_id" {
  value = azurerm_public_ip.pip.id
}

output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "public_fqdn" {
  value = azurerm_public_ip.pip.fqdn
}

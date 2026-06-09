output "frontdoor_profile_id" {
  value = azurerm_cdn_frontdoor_profile.profile.id
}

output "frontdoor_endpoint_fqdn" {
  value = azurerm_cdn_frontdoor_endpoint.endpoint.host_name
}

output "frontdoor_endpoint_url" {
  value = "http://${azurerm_cdn_frontdoor_endpoint.endpoint.host_name}"
}

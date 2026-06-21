# modules/appgw/outputs.tf

output "public_ip_address" {
  description = "The public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw.ip_address
}

output "public_ip_id" {
  description = "The ID of the public IP resource"
  value       = azurerm_public_ip.appgw.id
}

output "appgw_id" {
  description = "The ID of the Application Gateway"
  value       = azurerm_application_gateway.main.id
}

output "appgw_name" {
  description = "The name of the Application Gateway"
  value       = azurerm_application_gateway.main.name
}

output "waf_policy_id" {
  description = "The ID of the Web Application Firewall policy"
  value       = azurerm_web_application_firewall_policy.waf.id
}

output "identity_principal_id" {
  description = "The Principal ID of the User Assigned Identity"
  value       = azurerm_user_assigned_identity.appgw.principal_id
}

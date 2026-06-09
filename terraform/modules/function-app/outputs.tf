output "function_app_id" {
  value = azurerm_linux_function_app.func.id
}

output "function_app_name" {
  value = azurerm_linux_function_app.func.name
}

output "principal_id" {
  value = azurerm_linux_function_app.func.identity[0].principal_id
}

output "tenant_id" {
  value = azurerm_linux_function_app.func.identity[0].tenant_id
}

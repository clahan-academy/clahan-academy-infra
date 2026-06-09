output "automation_account_id" {
  value = azurerm_automation_account.aa.id
}

output "automation_account_name" {
  value = azurerm_automation_account.aa.name
}

output "principal_id" {
  value = azurerm_automation_account.aa.identity[0].principal_id
}

output "runbook_failover_name" {
  value = azurerm_automation_runbook.failover.name
}

output "runbook_failback_name" {
  value = azurerm_automation_runbook.failback.name
}

output "webhook_failover_id" {
  value = azurerm_automation_webhook.failover.id
}

output "webhook_failover_uri" {
  value     = azurerm_automation_webhook.failover.uri
  sensitive = true
}

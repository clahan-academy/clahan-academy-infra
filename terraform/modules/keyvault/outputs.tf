output "key_vault_id" {
  value = azurerm_key_vault.kv.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "secret_ids" {
  value = { for k, v in azurerm_key_vault_secret.secrets : k => v.id }
}

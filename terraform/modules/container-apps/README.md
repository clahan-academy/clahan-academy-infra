# Container Apps Module

This module deploys the Azure Container Apps Environment and the list of microservices based on the input configuration.

## Usage Example

```hcl
module "container_apps" {
  source                     = "./modules/container-apps"
  resource_group_name        = "rg-clahan-dev-india"
  location                   = "centralindia"
  region_short               = "india"
  subnet_id                  = module.networking.snet_containerapp_id
  log_analytics_workspace_id = "/subscriptions/.../workspaces/law"
  container_apps_map         = local.container_apps
  container_apps_min_replicas = 1
  key_vault_id               = module.keyvault.key_vault_id

  postgres_connection_string_secret_id   = module.keyvault.secret_ids["postgres-connection-string"]
  redis_connection_string_secret_id      = module.keyvault.secret_ids["redis-connection-string"]
  servicebus_connection_string_secret_id = module.keyvault.secret_ids["servicebus-connection-string"]
  smtp_password_secret_id                = module.keyvault.secret_ids["smtp-password"]

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

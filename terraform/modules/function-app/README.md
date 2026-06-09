# Function App Module

This module deploys a Linux-based Consumption Function App (Python 3.11 runtime) integrated with a VNet, utilizing Managed Identity and Key Vault secret references.

## Usage Example

```hcl
module "function_app" {
  source                               = "./modules/function-app"
  resource_group_name                  = "rg-clahan-dev-india"
  location                             = "centralindia"
  region_short                         = "india"
  subnet_id                            = module.networking.snet_function_id
  log_analytics_workspace_id           = "/subscriptions/.../workspaces/law"
  postgres_connection_string_secret_id = module.keyvault.secret_ids["postgres-connection-string"]
  random_suffix                        = "abcd"

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

# Automation Module

This module provisions an Azure Automation Account, imports PowerShell runbooks for DR failover and failback, sets up Contributors permissions on the primary and DR resource groups, and configures a webhook trigger for failover orchestration.

## Usage Example

```hcl
module "automation" {
  source                  = "./modules/automation"
  resource_group_name     = "rg-clahan-dev-global"
  location                = "centralindia"
  automation_account_name = "aa-clahan-dev-global"
  primary_rg_id           = "/subscriptions/.../resourceGroups/rg-clahan-dev-india"
  dr_rg_id                = "/subscriptions/.../resourceGroups/rg-clahan-dev-sea-dr"
  environment             = "dev"

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

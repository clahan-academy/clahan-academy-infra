# Key Vault Module

This module provisions an Azure Key Vault configured with Azure RBAC authorization, custom secret entries, and private endpoint setup.

## Usage Example

```hcl
module "keyvault" {
  source              = "./modules/keyvault"
  resource_group_name = "rg-clahan-dev-india"
  location            = "centralindia"
  region_short        = "india"
  random_suffix       = "abcd"
  subnet_id           = module.networking.snet_data_id
  private_dns_zone_id = module.networking.dns_zone_vault_id
  tenant_id           = data.azurerm_client_config.current.tenant_id

  secrets = {
    "my-secret" = "secret-value"
  }

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

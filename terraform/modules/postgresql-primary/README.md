# PostgreSQL Primary Module

This module deploys the primary Azure Database for PostgreSQL Flexible Server with databases, configuration parameters, and private endpoint configuration.

## Usage Example

```hcl
module "postgres_primary" {
  source              = "./modules/postgresql-primary"
  resource_group_name = "rg-clahan-dev-india"
  location            = "centralindia"
  server_name         = "pg-clahan-dev-india-main"
  admin_username      = "pgadmin"
  admin_password      = "SuperSecurePassword123"
  sku_name            = "GP_Standard_D2s_v3"
  storage_mb          = 32768
  subnet_id           = module.networking.snet_data_id
  private_dns_zone_id = module.networking.dns_zone_postgres_id

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

# PostgreSQL Replica Module

This module deploys a PostgreSQL read replica for cross-region Disaster Recovery.

## Usage Example

```hcl
module "postgres_replica" {
  source              = "./modules/postgresql-replica"
  resource_group_name = "rg-clahan-dev-sea-dr"
  location            = "southeastasia"
  server_name         = "pg-clahan-dev-sea-replica"
  primary_server_id   = "/subscriptions/.../providers/Microsoft.DBforPostgreSQL/flexibleServers/pg-clahan-dev-india-main"
  sku_name            = "GP_Standard_D2s_v3"
  storage_mb          = 32768
  subnet_id           = module.networking_sea.snet_data_id
  private_dns_zone_id = module.networking_sea.dns_zone_postgres_id

  tags = {
    Environment = "dev"
    Project     = "clahan"
    Role        = "DR"
  }
}
```

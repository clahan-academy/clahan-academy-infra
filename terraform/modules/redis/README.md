# Redis Cache Module

This module deploys a Native Azure Cache for Redis instance (Standard Tier) with Private Endpoint integration and private DNS configuration.

## Usage Example

```hcl
module "redis" {
  source              = "./modules/redis"
  resource_group_name = "rg-clahan-dev-india"
  location            = "centralindia"
  redis_name          = "redis-clahan-dev-india"
  sku_name            = "Standard"
  family              = "C"
  capacity            = 1
  subnet_id           = module.networking.snet_data_id
  private_dns_zone_id = module.networking.dns_zone_redis_id

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

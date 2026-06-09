# Service Bus Module

This module provisions an Azure Service Bus Namespace (Premium SKU for VNet integration) with topics, subscriptions, and private endpoint configuration.

## Usage Example

```hcl
module "servicebus" {
  source              = "./modules/servicebus"
  resource_group_name = "rg-clahan-dev-india"
  location            = "centralindia"
  namespace_name      = "sb-clahan-dev-india"
  subnet_id           = module.networking.snet_data_id
  private_dns_zone_id = module.networking.dns_zone_servicebus_id

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

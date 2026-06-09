# Networking Module

This module provisions the Virtual Network (VNet), subnets, Network Security Groups (NSGs), and Private DNS Zones required for the Clahan Academy environment.

## Usage Example

```hcl
module "networking" {
  source              = "./modules/networking"
  resource_group_name = "rg-clahan-dev-india"
  location            = "centralindia"
  region_short        = "india"
  vnet_name           = "vnet-clahan-dev-india"
  vnet_address_space  = ["10.0.0.0/16"]

  snet_appgw_cidr        = "10.0.1.0/24"
  snet_containerapp_cidr = "10.0.2.0/23"
  snet_data_cidr         = "10.0.4.0/24"
  snet_function_cidr     = "10.0.5.0/24"

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

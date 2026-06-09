# Front Door Module

This module provisions an Azure Front Door Standard profile, endpoints, origin groups, active and standby origins (pointing to Application Gateways), and forwarding routes.

## Usage Example

```hcl
module "frontdoor" {
  source               = "./modules/frontdoor"
  resource_group_name  = "rg-clahan-dev-global"
  profile_name         = "afd-clahan-dev-global"
  primary_appgw_fqdn   = "pip-clahan-india.centralindia.cloudapp.azure.com"
  secondary_appgw_fqdn = "pip-clahan-sea.southeastasia.cloudapp.azure.com"
  random_suffix        = "abcd"

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

# Application Gateway Module

This module provisions an Azure Application Gateway (WAF_v2 SKU) configured with autoscaling, a Web Application Firewall (WAF) policy, backend routing rules to Container Apps, and health probes.

## Usage Example

```hcl
module "appgateway" {
  source              = "./modules/appgateway"
  resource_group_name = "rg-clahan-dev-india"
  location            = "centralindia"
  region_short        = "india"
  appgw_name          = "appgw-clahan-dev-india"
  subnet_id           = module.networking.snet_appgw_id
  backend_fqdn        = module.container_apps.container_apps_env_default_domain
  random_suffix       = "abcd"
  appgw_capacity      = 2
  enable_waf          = true

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

# Monitoring Module

This module provisions Azure Action Groups (for administrator emails and automated DR failover), metric alerts for resource thresholds (PostgreSQL CPU/Storage, WAF blocks, App Gateway 5xx status codes, Container App replicas, Front Door health), and Azure Monitor Diagnostic Settings forwarding to a shared Log Analytics Workspace.

## Usage Example

```hcl
module "monitoring" {
  source                        = "./modules/monitoring"
  resource_group_name           = "rg-clahan-dev-global"
  location                      = "centralindia"
  log_analytics_workspace_id    = "/subscriptions/.../workspaces/law"
  admin_email                   = "admin@example.com"
  automation_account_id         = module.automation.automation_account_id
  runbook_failover_name         = module.automation.runbook_failover_name
  failover_webhook_id           = module.automation.webhook_failover_id
  failover_webhook_uri          = module.automation.webhook_failover_uri
  
  primary_postgres_id           = module.postgres_india.server_id
  primary_appgw_id              = module.appgateway_india.appgw_id
  primary_keyvault_id           = module.kv_india.key_vault_id
  primary_servicebus_id         = module.sb_india.namespace_id
  primary_container_apps_env_id = module.container_apps_india.container_apps_env_id
  primary_function_app_id       = module.function_india.function_app_id
  
  enable_dr                     = false
  enable_frontdoor              = false

  tags = {
    Environment = "dev"
    Project     = "clahan"
  }
}
```

# Retrieve client config for tenant ID and current deployer object ID
data "azurerm_client_config" "current" {}

# Generate a random 4-character suffix for globally-unique naming (Key Vault, Storage Accounts)
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Generate a secure random password for the PostgreSQL Flexible Server admin
resource "random_password" "pg_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# =====================================================================
# RESOURCE GROUPS
# =====================================================================

# Primary Resource Group (Central India)
resource "azurerm_resource_group" "rg_india" {
  name     = "rg-clahan-${var.environment}-india"
  location = var.primary_location
  tags     = local.primary_tags
}

# Disaster Recovery Resource Group (Southeast Asia) - Conditional
resource "azurerm_resource_group" "rg_sea" {
  count    = var.enable_dr ? 1 : 0
  name     = "rg-clahan-${var.environment}-sea-dr"
  location = var.dr_location
  tags     = local.dr_tags
}

# Shared Global Resource Group (Central India)
resource "azurerm_resource_group" "rg_global" {
  name     = "rg-clahan-${var.environment}-global"
  location = var.primary_location
  tags     = local.global_tags
}

# =====================================================================
# SHARED GLOBAL OBSERVABILITY
# =====================================================================

# Shared Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-clahan-${var.environment}-global"
  location            = azurerm_resource_group.rg_global.location
  resource_group_name = azurerm_resource_group.rg_global.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.global_tags
}

# Shared Application Insights
resource "azurerm_application_insights" "appi" {
  name                = "appi-clahan-${var.environment}-global"
  location            = azurerm_resource_group.rg_global.location
  resource_group_name = azurerm_resource_group.rg_global.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  tags                = local.global_tags
}

# =====================================================================
# PRIMARY REGION (INDIA) INFRASTRUCTURE
# =====================================================================

module "networking_india" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.rg_india.name
  location            = azurerm_resource_group.rg_india.location
  region_short        = "india"
  vnet_name           = "vnet-clahan-${var.environment}-india"
  vnet_address_space  = ["10.0.0.0/16"]

  snet_appgw_cidr        = "10.0.1.0/24"
  snet_containerapp_cidr = "10.0.2.0/23"
  snet_data_cidr         = "10.0.4.0/24"
  snet_function_cidr     = "10.0.5.0/24"

  tags = local.primary_tags
}

module "postgres_india" {
  source              = "./modules/postgresql-primary"
  resource_group_name = azurerm_resource_group.rg_india.name
  location            = azurerm_resource_group.rg_india.location
  server_name         = "pg-clahan-${var.environment}-india-main"
  admin_username      = "pgadmin"
  admin_password      = random_password.pg_password.result
  sku_name            = var.postgres_sku
  storage_mb          = var.postgres_storage_mb
  subnet_id           = module.networking_india.snet_data_id
  private_dns_zone_id = module.networking_india.dns_zone_postgres_id
  tags                = local.primary_tags
}

module "redis_india" {
  source              = "./modules/redis"
  resource_group_name = azurerm_resource_group.rg_india.name
  location            = azurerm_resource_group.rg_india.location
  redis_name          = "redis-clahan-${var.environment}-india"
  sku_name            = var.redis_sku
  family              = var.redis_family
  capacity            = var.redis_capacity
  subnet_id           = module.networking_india.snet_data_id
  private_dns_zone_id = module.networking_india.dns_zone_redis_id
  tags                = local.primary_tags
}

module "sb_india" {
  source              = "./modules/servicebus"
  resource_group_name = azurerm_resource_group.rg_india.name
  location            = azurerm_resource_group.rg_india.location
  namespace_name      = "sb-clahan-${var.environment}-india"
  sku                 = "Premium" # Required for private endpoints
  subnet_id           = module.networking_india.snet_data_id
  private_dns_zone_id = module.networking_india.dns_zone_servicebus_id
  tags                = local.primary_tags
}

module "kv_india" {
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.rg_india.name
  location            = azurerm_resource_group.rg_india.location
  environment         = var.environment
  region_short        = "india"
  random_suffix       = random_string.suffix.result
  subnet_id           = module.networking_india.snet_data_id
  private_dns_zone_id = module.networking_india.dns_zone_vault_id
  tenant_id           = data.azurerm_client_config.current.tenant_id

  secrets = {
    "postgres-admin-password"      = random_password.pg_password.result
    "postgres-connection-string"   = "Host=${module.postgres_india.fqdn};Port=5432;Database=postgres;Username=${module.postgres_india.admin_username};Password=${random_password.pg_password.result};Ssl Mode=Require;"
    "redis-connection-string"      = module.redis_india.connection_string
    "servicebus-connection-string" = module.sb_india.primary_connection_string
    "smtp-password"                = var.smtp_password
    "smtp-host"                    = var.smtp_host
    "smtp-port"                    = var.smtp_port
  }

  tags = local.primary_tags
}

module "container_apps_india" {
  source                     = "./modules/container-apps"
  resource_group_name        = azurerm_resource_group.rg_india.name
  location                   = azurerm_resource_group.rg_india.location
  environment                = var.environment
  region_short               = "india"
  subnet_id                  = module.networking_india.snet_containerapp_id
  vnet_id                    = module.networking_india.vnet_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  container_apps_map         = local.container_apps
  container_apps_min_replicas = var.container_apps_min_replicas
  key_vault_id               = module.kv_india.key_vault_id

  postgres_connection_string_secret_id   = module.kv_india.secret_ids["postgres-connection-string"]
  redis_connection_string_secret_id      = module.kv_india.secret_ids["redis-connection-string"]
  servicebus_connection_string_secret_id = module.kv_india.secret_ids["servicebus-connection-string"]
  smtp_password_secret_id                = module.kv_india.secret_ids["smtp-password"]

  tags = local.primary_tags
}

module "appgateway_india" {
  source              = "./modules/appgateway"
  resource_group_name = azurerm_resource_group.rg_india.name
  location            = azurerm_resource_group.rg_india.location
  region_short        = "india"
  appgw_name          = "appgw-clahan-${var.environment}-india"
  subnet_id           = module.networking_india.snet_appgw_id
  random_suffix       = random_string.suffix.result
  appgw_capacity      = var.appgw_capacity
  enable_waf          = var.enable_waf
  backend_fqdn        = module.container_apps_india.container_app_fqdns["frontend-service"]
  tags                = local.primary_tags
}

module "function_india" {
  source                               = "./modules/function-app"
  resource_group_name                  = azurerm_resource_group.rg_india.name
  location                             = azurerm_resource_group.rg_india.location
  environment                          = var.environment
  region_short                         = "india"
  subnet_id                            = module.networking_india.snet_function_id
  log_analytics_workspace_id           = azurerm_log_analytics_workspace.law.id
  postgres_connection_string_secret_id = module.kv_india.secret_ids["postgres-connection-string"]
  random_suffix                        = random_string.suffix.result
  tags                                 = local.primary_tags
}

# =====================================================================
# DR STANDBY REGION (INDONESIA / SEA) INFRASTRUCTURE - CONDITIONAL
# =====================================================================

module "networking_sea" {
  count               = var.enable_dr ? 1 : 0
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.rg_sea[0].name
  location            = azurerm_resource_group.rg_sea[0].location
  region_short        = "sea"
  vnet_name           = "vnet-clahan-${var.environment}-sea"
  vnet_address_space  = ["11.0.0.0/16"]

  snet_appgw_cidr        = "11.0.1.0/24"
  snet_containerapp_cidr = "11.0.2.0/23"
  snet_data_cidr         = "11.0.4.0/24"
  snet_function_cidr     = "11.0.5.0/24"

  tags = local.dr_tags
}

module "postgres_sea" {
  count               = var.enable_dr ? 1 : 0
  source              = "./modules/postgresql-replica"
  resource_group_name = azurerm_resource_group.rg_sea[0].name
  location            = azurerm_resource_group.rg_sea[0].location
  server_name         = "pg-clahan-${var.environment}-sea-replica"
  primary_server_id   = module.postgres_india.server_id
  sku_name            = var.postgres_sku
  storage_mb          = var.postgres_storage_mb
  subnet_id           = module.networking_sea[0].snet_data_id
  private_dns_zone_id = module.networking_sea[0].dns_zone_postgres_id
  tags                = local.dr_tags

  depends_on = [module.postgres_india]
}

module "redis_sea" {
  count               = var.enable_dr ? 1 : 0
  source              = "./modules/redis"
  resource_group_name = azurerm_resource_group.rg_sea[0].name
  location            = azurerm_resource_group.rg_sea[0].location
  redis_name          = "redis-clahan-${var.environment}-sea"
  sku_name            = var.redis_sku
  family              = var.redis_family
  capacity            = var.redis_capacity
  subnet_id           = module.networking_sea[0].snet_data_id
  private_dns_zone_id = module.networking_sea[0].dns_zone_redis_id
  tags                = local.dr_tags
}

module "sb_sea" {
  count               = var.enable_dr ? 1 : 0
  source              = "./modules/servicebus"
  resource_group_name = azurerm_resource_group.rg_sea[0].name
  location            = azurerm_resource_group.rg_sea[0].location
  namespace_name      = "sb-clahan-${var.environment}-sea"
  sku                 = "Premium"
  subnet_id           = module.networking_sea[0].snet_data_id
  private_dns_zone_id = module.networking_sea[0].dns_zone_servicebus_id
  tags                = local.dr_tags
}

module "kv_sea" {
  count               = var.enable_dr ? 1 : 0
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.rg_sea[0].name
  location            = azurerm_resource_group.rg_sea[0].location
  environment         = var.environment
  region_short        = "sea"
  random_suffix       = random_string.suffix.result
  subnet_id           = module.networking_sea[0].snet_data_id
  private_dns_zone_id = module.networking_sea[0].dns_zone_vault_id
  tenant_id           = data.azurerm_client_config.current.tenant_id

  secrets = {
    "postgres-admin-password"      = random_password.pg_password.result
    "postgres-connection-string"   = "Host=${module.postgres_sea[0].fqdn};Port=5432;Database=postgres;Username=${module.postgres_india.admin_username};Password=${random_password.pg_password.result};Ssl Mode=Require;"
    "redis-connection-string"      = module.redis_sea[0].connection_string
    "servicebus-connection-string" = module.sb_sea[0].primary_connection_string
    "smtp-password"                = var.smtp_password
    "smtp-host"                    = var.smtp_host
    "smtp-port"                    = var.smtp_port
  }

  tags = local.dr_tags
}

module "container_apps_sea" {
  count                      = var.enable_dr ? 1 : 0
  source                     = "./modules/container-apps"
  resource_group_name        = azurerm_resource_group.rg_sea[0].name
  location                   = azurerm_resource_group.rg_sea[0].location
  environment                = var.environment
  region_short               = "sea"
  subnet_id                  = module.networking_sea[0].snet_containerapp_id
  vnet_id                    = module.networking_sea[0].vnet_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  container_apps_map         = local.container_apps
  container_apps_min_replicas = 0 # Standby region: initially scaled down to 0 replicas
  key_vault_id               = module.kv_sea[0].key_vault_id

  postgres_connection_string_secret_id   = module.kv_sea[0].secret_ids["postgres-connection-string"]
  redis_connection_string_secret_id      = module.kv_sea[0].secret_ids["redis-connection-string"]
  servicebus_connection_string_secret_id = module.kv_sea[0].secret_ids["servicebus-connection-string"]
  smtp_password_secret_id                = module.kv_sea[0].secret_ids["smtp-password"]

  tags = local.dr_tags
}

module "appgateway_sea" {
  count               = var.enable_dr ? 1 : 0
  source              = "./modules/appgateway"
  resource_group_name = azurerm_resource_group.rg_sea[0].name
  location            = azurerm_resource_group.rg_sea[0].location
  region_short        = "sea"
  appgw_name          = "appgw-clahan-${var.environment}-sea"
  subnet_id           = module.networking_sea[0].snet_appgw_id
  random_suffix       = random_string.suffix.result
  appgw_capacity      = var.appgw_capacity
  enable_waf          = var.enable_waf
  backend_fqdn        = module.container_apps_sea[0].container_app_fqdns["frontend-service"]
  tags                = local.dr_tags
}

module "function_sea" {
  count                                = var.enable_dr ? 1 : 0
  source                               = "./modules/function-app"
  resource_group_name                  = azurerm_resource_group.rg_sea[0].name
  location                             = azurerm_resource_group.rg_sea[0].location
  environment                          = var.environment
  region_short                         = "sea"
  subnet_id                            = module.networking_sea[0].snet_function_id
  log_analytics_workspace_id           = azurerm_log_analytics_workspace.law.id
  postgres_connection_string_secret_id = module.kv_sea[0].secret_ids["postgres-connection-string"]
  random_suffix                        = random_string.suffix.result
  tags                                 = local.dr_tags
}

# =====================================================================
# GLOBAL TRAFFIC & DR AUTOMATION (SHARED RESOURCES)
# =====================================================================

module "frontdoor" {
  count                = var.enable_dr ? 1 : 0
  source               = "./modules/frontdoor"
  resource_group_name  = azurerm_resource_group.rg_global.name
  profile_name         = "afd-clahan-${var.environment}-global"
  primary_appgw_fqdn   = module.appgateway_india.public_fqdn
  secondary_appgw_fqdn = module.appgateway_sea[0].public_fqdn
  random_suffix        = random_string.suffix.result
  tags                 = local.global_tags
}

module "automation" {
  source                  = "./modules/automation"
  resource_group_name     = azurerm_resource_group.rg_global.name
  location                = "eastus"
  automation_account_name = "aa-clahan-${var.environment}-global"
  primary_rg_id           = azurerm_resource_group.rg_india.id
  dr_rg_id                = var.enable_dr ? azurerm_resource_group.rg_sea[0].id : ""
  environment             = var.environment
  tags                    = local.global_tags
}

module "monitoring" {
  source                     = "./modules/monitoring"
  resource_group_name        = azurerm_resource_group.rg_global.name
  location                   = azurerm_resource_group.rg_global.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  admin_email                = var.admin_email
  enable_dr                  = var.enable_dr
  enable_frontdoor           = var.enable_dr # Enabled Front Door monitoring only if DR is enabled
  frontdoor_profile_id       = var.enable_dr ? module.frontdoor[0].frontdoor_profile_id : ""
  automation_account_id      = module.automation.automation_account_id
  runbook_failover_name      = module.automation.runbook_failover_name
  failover_webhook_id        = module.automation.webhook_failover_id
  failover_webhook_uri       = module.automation.webhook_failover_uri
  
  primary_postgres_id           = module.postgres_india.server_id
  replica_postgres_id           = var.enable_dr ? module.postgres_sea[0].server_id : ""
  primary_appgw_id              = module.appgateway_india.appgw_id
  replica_appgw_id              = var.enable_dr ? module.appgateway_sea[0].appgw_id : ""
  primary_keyvault_id           = module.kv_india.key_vault_id
  replica_keyvault_id           = var.enable_dr ? module.kv_sea[0].key_vault_id : ""
  primary_servicebus_id         = module.sb_india.namespace_id
  replica_servicebus_id         = var.enable_dr ? module.sb_sea[0].namespace_id : ""
  primary_container_apps_env_id = module.container_apps_india.container_apps_env_id
  replica_container_apps_env_id = var.enable_dr ? module.container_apps_sea[0].container_apps_env_id : ""
  primary_function_app_id       = module.function_india.function_app_id
  replica_function_app_id       = var.enable_dr ? module.function_sea[0].function_app_id : ""

  tags = local.global_tags
}

# =====================================================================
# SECURITY & RBAC RULE ASSIGNMENTS
# =====================================================================

# 1. India Region KV Access Role Assignments
resource "azurerm_role_assignment" "ca_india_kv_access" {
  for_each             = local.container_apps
  scope                = module.kv_india.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.container_apps_india.container_app_identities[each.key]
}

resource "azurerm_role_assignment" "fn_india_kv_access" {
  scope                = module.kv_india.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function_india.principal_id
}

resource "azurerm_role_assignment" "aa_india_kv_access" {
  scope                = module.kv_india.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = module.automation.principal_id
}

# 2. SEA Region KV Access Role Assignments - Conditional
resource "azurerm_role_assignment" "ca_sea_kv_access" {
  for_each             = { for k, v in local.container_apps : k => v if var.enable_dr }
  scope                = module.kv_sea[0].key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.container_apps_sea[0].container_app_identities[each.key]
}

resource "azurerm_role_assignment" "fn_sea_kv_access" {
  count                = var.enable_dr ? 1 : 0
  scope                = module.kv_sea[0].key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function_sea[0].principal_id
}

resource "azurerm_role_assignment" "aa_sea_kv_access" {
  count                = var.enable_dr ? 1 : 0
  scope                = module.kv_sea[0].key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = module.automation.principal_id
}

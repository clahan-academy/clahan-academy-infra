# terraform/main.tf
# Main entrypoint for Clahan Academy V2 Infrastructure

locals {
  tags = {
    Environment = var.environment
    Project     = "clahan-academy"
    Owner       = "M-VIGNESH3"
    ManagedBy   = "terraform"
    Region      = var.location
  }
}

data "azurerm_client_config" "current" {}

module "networking" {
  source = "./modules/networking"

  resource_group_name = var.resource_group_name
  location            = var.location
  enable_bastion      = var.enable_jumpvm
  tags                = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = module.networking.resource_group_name
  location            = var.location
  admin_email         = var.admin_email
  tags                = local.tags
}

module "acr" {
  source = "./modules/acr"

  resource_group_name        = module.networking.resource_group_name
  location                   = var.location
  subnet_privateendpoints_id = module.networking.subnet_privateendpoints_id
  environment                = var.environment
  tags                       = local.tags
}

module "storage" {
  source = "./modules/storage"

  resource_group_name        = module.networking.resource_group_name
  location                   = var.location
  subnet_privateendpoints_id = module.networking.subnet_privateendpoints_id
  deployer_object_id         = var.deployer_object_id
  environment                = var.environment
  tags                       = local.tags
}

module "postgres" {
  source = "./modules/postgres"

  resource_group_name          = module.networking.resource_group_name
  location                     = var.location
  sku_name                     = var.postgres_sku
  storage_mb                   = var.postgres_storage_mb
  backup_retention_days        = var.postgres_backup_days
  geo_redundant_backup_enabled = var.postgres_geo_redundant
  environment                  = var.environment
  subnet_id                    = module.networking.subnet_postgres_id
  private_dns_zone_id          = module.networking.private_dns_zone_ids["postgres"]
  tags                         = local.tags
}

module "keyvault" {
  source = "./modules/keyvault"

  resource_group_name = module.networking.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  deployer_object_id  = var.deployer_object_id
  github_sp_object_id = var.github_sp_object_id
  key_vault_name      = var.key_vault_name
  tags                = local.tags

  secrets = {
    blob_storage_account = module.storage.storage_account_name
    blob_storage_key     = module.storage.primary_access_key
  }
}

module "aks" {
  source = "./modules/aks"

  cluster_name               = "aks-clahan-academy"
  location                   = var.location
  resource_group_name        = module.networking.resource_group_name
  resource_group_id          = module.networking.resource_group_id
  kubernetes_version         = "1.35"
  dns_prefix                 = "clahan"
  subnet_aks_id              = module.networking.subnet_aks_id
  vnet_id                    = module.networking.vnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  acr_id                     = module.acr.acr_id
  app_node_vm_size           = var.app_node_vm_size
  app_node_count             = var.app_node_count
  app_min_count              = var.app_min_count
  app_max_count              = var.app_max_count
  tags                       = local.tags
  environment                = var.environment
}

module "identity" {
  source = "./modules/identity"

  resource_group_name = module.networking.resource_group_name
  location            = var.location
  aks_oidc_issuer_url = module.aks.oidc_issuer_url
  key_vault_id        = module.keyvault.key_vault_id
  storage_account_id  = module.storage.storage_account_id
  acr_id              = module.acr.acr_id
  github_sp_object_id = var.github_sp_object_id
  tags                = local.tags
  namespace           = var.environment == "prod" ? "clahan-production" : "clahan-dev"
}

module "jumpvm" {
  count  = var.enable_jumpvm ? 1 : 0
  source = "./modules/jumpvm"

  resource_group_name = module.networking.resource_group_name
  location            = var.location
  subnet_mgmt_id      = module.networking.subnet_mgmt_id
  aks_cluster_id      = module.aks.cluster_id
  key_vault_id        = module.keyvault.key_vault_id
  tags                = local.tags
}

# Redis secrets defined directly (using in-cluster Redis)
resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "redis-connection-string"
  value        = "redis://redis:6379"
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [module.keyvault]
}

resource "azurerm_key_vault_secret" "redis_primary_key" {
  name         = "redis-primary-key"
  value        = "not-applicable"
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [module.keyvault]
}

module "appgw" {
  source = "./modules/appgw"

  resource_group_name = module.networking.resource_group_name
  location            = var.location
  subnet_appgw_id     = module.networking.subnet_appgw_id
  key_vault_id        = module.keyvault.key_vault_id
  domain_name         = var.domain_name
  tags                = local.tags
}

# DB Secrets at root level to avoid circular dependency
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = module.postgres.app_connection_string
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [module.keyvault, module.postgres]
}

resource "azurerm_key_vault_secret" "judge0_db_connection_string" {
  name         = "judge0-db-connection-string"
  value        = module.postgres.judge0_connection_string
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [module.keyvault, module.postgres]
}

resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  value        = module.postgres.admin_password
  key_vault_id = module.keyvault.key_vault_id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [module.keyvault, module.postgres]
}


# persistent/main.tf
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
  source = "../modules/networking"

  resource_group_name = var.resource_group_name
  location            = var.location
  enable_bastion      = var.enable_jumpvm
  tags                = local.tags
}

module "monitoring" {
  source = "../modules/monitoring"

  resource_group_name = module.networking.resource_group_name
  location            = var.location
  admin_email         = var.admin_email
  tags                = local.tags
}

module "acr" {
  source = "../modules/acr"

  resource_group_name        = module.networking.resource_group_name
  location                   = var.location
  subnet_privateendpoints_id = module.networking.subnet_privateendpoints_id
  environment                = var.environment
  tags                       = local.tags
}

module "storage" {
  source = "../modules/storage"

  resource_group_name        = module.networking.resource_group_name
  location                   = var.location
  subnet_privateendpoints_id = module.networking.subnet_privateendpoints_id
  deployer_object_id         = var.deployer_object_id
  environment                = var.environment
  tags                       = local.tags
}

module "postgres" {
  source = "../modules/postgres"

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
  source = "../modules/keyvault"

  resource_group_name = module.networking.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  deployer_object_id  = var.deployer_object_id
  github_sp_object_id = var.github_sp_object_id
  key_vault_name      = var.key_vault_name
  tags                = local.tags
}

# Persistent Public IP for Application Gateway (keeps the same IP on recreate)
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-clahan-academy"
  resource_group_name = module.networking.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

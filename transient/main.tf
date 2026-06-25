# transient/main.tf
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

# Read remote state from the persistent layer
data "terraform_remote_state" "persistent" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-clahan-tfstate"
    storage_account_name = "stclahantfstate65bf2554"
    container_name       = "tfstate"
    key                  = "persistent-${var.environment}.tfstate"
  }
}

module "aks" {
  source = "../modules/aks"

  cluster_name               = "aks-clahan-academy"
  location                   = var.location
  resource_group_name        = data.terraform_remote_state.persistent.outputs.resource_group_name
  resource_group_id          = data.terraform_remote_state.persistent.outputs.resource_group_id
  kubernetes_version         = "1.35"
  dns_prefix                 = "clahan"
  subnet_aks_id              = data.terraform_remote_state.persistent.outputs.subnet_aks_id
  vnet_id                    = data.terraform_remote_state.persistent.outputs.vnet_id
  log_analytics_workspace_id = data.terraform_remote_state.persistent.outputs.log_analytics_workspace_id
  acr_id                     = data.terraform_remote_state.persistent.outputs.acr_id
  app_node_vm_size           = var.app_node_vm_size
  app_node_count             = var.app_node_count
  app_min_count              = var.app_min_count
  app_max_count              = var.app_max_count
  tags                       = local.tags
  environment                = var.environment
}

module "identity" {
  source = "../modules/identity"

  resource_group_name = data.terraform_remote_state.persistent.outputs.resource_group_name
  location            = var.location
  aks_oidc_issuer_url = module.aks.oidc_issuer_url
  key_vault_id        = data.terraform_remote_state.persistent.outputs.key_vault_id
  storage_account_id  = data.terraform_remote_state.persistent.outputs.storage_account_id
  acr_id              = data.terraform_remote_state.persistent.outputs.acr_id
  github_sp_object_id = var.github_sp_object_id
  tags                = local.tags
  namespace           = var.environment == "prod" ? "clahan-production" : "clahan-dev"
}

module "jumpvm" {
  count  = var.enable_jumpvm ? 1 : 0
  source = "../modules/jumpvm"

  resource_group_name = data.terraform_remote_state.persistent.outputs.resource_group_name
  location            = var.location
  subnet_mgmt_id      = data.terraform_remote_state.persistent.outputs.subnet_mgmt_id
  aks_cluster_id      = module.aks.cluster_id
  key_vault_id        = data.terraform_remote_state.persistent.outputs.key_vault_id
  tags                = local.tags
}

module "functions" {
  count  = var.enable_functions ? 1 : 0
  source = "../modules/functions"

  subscription_id                  = var.subscription_id
  resource_group_name              = data.terraform_remote_state.persistent.outputs.resource_group_name
  location                         = "eastus"
  storage_account_name             = data.terraform_remote_state.persistent.outputs.storage_account_name
  storage_account_key              = data.terraform_remote_state.persistent.outputs.storage_primary_access_key
  app_insights_instrumentation_key = data.terraform_remote_state.persistent.outputs.app_insights_instrumentation_key
  app_insights_connection_string   = data.terraform_remote_state.persistent.outputs.app_insights_connection_string
  key_vault_id                     = data.terraform_remote_state.persistent.outputs.key_vault_id
  admin_email                      = var.admin_email
  tags                             = local.tags
}

module "appgw" {
  source = "../modules/appgw"

  resource_group_name = data.terraform_remote_state.persistent.outputs.resource_group_name
  location            = var.location
  subnet_appgw_id     = data.terraform_remote_state.persistent.outputs.subnet_appgw_id
  key_vault_id        = data.terraform_remote_state.persistent.outputs.key_vault_id
  key_vault_name      = data.terraform_remote_state.persistent.outputs.key_vault_name
  domain_name         = var.domain_name
  tags                = local.tags
}

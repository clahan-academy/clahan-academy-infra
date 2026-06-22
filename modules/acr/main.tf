# terraform/modules/acr/main.tf

locals {
  tags = merge(var.tags, {
    module = "acr"
  })
}

# Azure Container Registry - stores all application Docker images
resource "azurerm_container_registry" "main" {
  name                          = var.environment == "prod" ? "acrclahan65bf2554" : "acrclahan65bf2554dev"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = true
  zone_redundancy_enabled       = false

  tags = local.tags
}

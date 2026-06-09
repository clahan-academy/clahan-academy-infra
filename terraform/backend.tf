terraform {
  backend "azurerm" {
    resource_group_name  = "rg-clahan-academy-global"
    storage_account_name = "stclahantfstate"
    container_name       = "tfstate"
    key                  = "clahan-academy.tfstate"
    use_azuread_auth     = false
  }
}

# terraform/backend.tf
# Backend configuration for Clahan Academy V2 Infrastructure

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-clahan-tfstate"
    storage_account_name = "stclahantfstate65bf2554"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

# imports.tf
# Temporary import block to restore AKS cluster into Terraform state.
# REMOVE THIS FILE after a successful terraform apply.

import {
  to = module.aks.azurerm_kubernetes_cluster.main
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.ContainerService/managedClusters/aks-clahan-academy"
}

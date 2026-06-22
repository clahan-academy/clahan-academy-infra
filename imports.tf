# imports.tf
# Temporary import blocks to restore Terraform state after failed apply.
# REMOVE THIS FILE after a successful terraform apply.

import {
  to = module.aks.azurerm_kubernetes_cluster.main
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.ContainerService/managedClusters/aks-clahan-academy"
}

import {
  to = module.aks.azurerm_kubernetes_cluster_node_pool.ai
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.ContainerService/managedClusters/aks-clahan-academy/agentPools/ai"
}

import {
  to = module.postgres.azurerm_postgresql_flexible_server.main
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-clahan-65bf2554"
}

import {
  to = module.postgres.azurerm_postgresql_flexible_server_database.clahan_academy
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-clahan-65bf2554/databases/clahan_academy"
}

import {
  to = module.postgres.azurerm_postgresql_flexible_server_database.judge0
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-clahan-65bf2554/databases/judge0"
}

import {
  to = module.postgres.azurerm_postgresql_flexible_server_firewall_rule.azure_services
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql-clahan-65bf2554/firewallRules/allow-azure-services"
}

import {
  to = module.redis.azurerm_redis_cache.main[0]
  id = "/subscriptions/65bf2554-8090-4538-9c38-8a6e9c5f6f22/resourceGroups/rg-clahan-prod/providers/Microsoft.Cache/redis/redis-clahan-prod-09a4ue"
}

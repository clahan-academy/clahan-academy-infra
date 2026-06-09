# DR PostgreSQL Flexible Server Read Replica
resource "azurerm_postgresql_flexible_server" "replica" {
  name                         = var.server_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  create_mode                  = "Replica"
  source_server_id             = var.primary_server_id
  sku_name                     = var.sku_name
  storage_mb                   = var.storage_mb

  tags = var.tags

  lifecycle {
    ignore_changes = [
      zone,
      high_availability
    ]
  }
}

# Private Endpoint for Replica PostgreSQL
resource "azurerm_private_endpoint" "replica_pe" {
  name                = "pe-${var.server_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-${var.server_name}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.replica.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }

  private_dns_zone_group {
    name                 = "dns-group-postgres-replica"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

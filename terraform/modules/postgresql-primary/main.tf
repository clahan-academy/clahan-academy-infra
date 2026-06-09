# Primary PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "primary" {
  name                         = var.server_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "15"
  administrator_login          = var.admin_username
  administrator_password       = var.admin_password
  sku_name                     = var.sku_name
  storage_mb                   = var.storage_mb
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  tags = var.tags

  lifecycle {
    ignore_changes = [
      zone,
      high_availability
    ]
  }
}

# Set max_connections to 800
resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.primary.id
  value     = "800"
}

# Databases
resource "azurerm_postgresql_flexible_server_database" "databases" {
  for_each  = toset(["auth_db", "exam_db", "notification_db", "proctoring_db", "admin_db", "student_db"])
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.primary.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Private Endpoint for PostgreSQL
resource "azurerm_private_endpoint" "postgres_pe" {
  name                = "pe-${var.server_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-${var.server_name}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.primary.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }

  private_dns_zone_group {
    name                 = "dns-group-postgres"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

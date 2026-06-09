# Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                           = "cae-clahan-${var.environment}-${var.region_short}"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  infrastructure_subnet_id       = var.subnet_id
  internal_load_balancer_enabled = true
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  zone_redundancy_enabled        = false

  tags = var.tags
}

# Container Apps
resource "azurerm_container_app" "app" {
  for_each                     = var.container_apps_map
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    external_enabled = lookup(each.value, "external", false)
    target_port      = each.value.port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Reference secrets from Key Vault using System-Assigned identity
  secret {
    name                = "postgres-connection-string"
    key_vault_secret_id = var.postgres_connection_string_secret_id
    identity            = "System"
  }

  secret {
    name                = "redis-connection-string"
    key_vault_secret_id = var.redis_connection_string_secret_id
    identity            = "System"
  }

  secret {
    name                = "servicebus-connection-string"
    key_vault_secret_id = var.servicebus_connection_string_secret_id
    identity            = "System"
  }

  # Dynamic SMTP secret for the notification service
  dynamic "secret" {
    for_each = each.key == "notification-service" ? [1] : []
    content {
      name                = "smtp-password"
      key_vault_secret_id = var.smtp_password_secret_id
      identity            = "System"
    }
  }

  template {
    container {
      name    = each.key
      image   = each.value.image
      cpu     = each.value.cpu
      memory  = each.value.memory
      command = lookup(each.value, "command", null)
      args    = lookup(each.value, "args", null)

      env {
        name        = "DATABASE_URL"
        secret_name = "postgres-connection-string"
      }

      env {
        name        = "REDIS_URL"
        secret_name = "redis-connection-string"
      }

      env {
        name        = "SERVICEBUS_CONNECTION"
        secret_name = "servicebus-connection-string"
      }

      env {
        name  = "REGION"
        value = var.region_short
      }

      env {
        name  = "PORT"
        value = tostring(each.value.port)
      }

      # Dynamic environment variables from the service map
      dynamic "env" {
        for_each = lookup(each.value, "env", {})
        content {
          name  = env.key
          value = env.value
        }
      }

      # Dynamic environment variable for notification service
      dynamic "env" {
        for_each = each.key == "notification-service" ? [1] : []
        content {
          name        = "SMTP_PASSWORD"
          secret_name = "smtp-password"
        }
      }
    }

    min_replicas = var.region_short == "india" ? var.container_apps_min_replicas : 0
    max_replicas = each.value.max_replicas

    http_scale_rule {
      name                = "http-scale"
      concurrent_requests = "50"
    }
  }

  tags = var.tags
}

# Private DNS Zone for the Container Apps Environment default domain
resource "azurerm_private_dns_zone" "aca_dns" {
  name                = azurerm_container_app_environment.env.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aca_dns_link" {
  name                  = "aca-dns-link-${var.region_short}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aca_dns.name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "aca_dns_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.aca_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.env.static_ip_address]
}

resource "azurerm_private_dns_a_record" "aca_dns_apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.aca_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.env.static_ip_address]
}

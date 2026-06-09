# Action Group: Administrator Notifications
resource "azurerm_monitor_action_group" "admin" {
  name                = "ag-clahan-admin"
  resource_group_name = var.resource_group_name
  short_name          = "clahan-admin"

  email_receiver {
    name                    = "admin-email"
    email_address           = var.admin_email
    use_common_alert_schema = true
  }

  tags = var.tags
}

# Action Group: DR Failover Action (Triggers Automation Runbook + Email)
resource "azurerm_monitor_action_group" "dr" {
  name                = "ag-clahan-dr"
  resource_group_name = var.resource_group_name
  short_name          = "clahan-dr"

  email_receiver {
    name                    = "dr-admin-email"
    email_address           = var.admin_email
    use_common_alert_schema = true
  }

  automation_runbook_receiver {
    name                    = "dr-failover-runbook-receiver"
    automation_account_id   = var.automation_account_id
    runbook_name            = var.runbook_failover_name
    webhook_resource_id     = var.failover_webhook_id
    service_uri             = var.failover_webhook_uri
    is_global_runbook       = false
    use_common_alert_schema = true
  }

  tags = var.tags
}

# Alert 1: PostgreSQL CPU High
resource "azurerm_monitor_metric_alert" "pg_cpu_high" {
  name                = "alert-pg-cpu-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.primary_postgres_id]
  description         = "Triggers when Primary PostgreSQL CPU exceeds 80% for 5 minutes."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.admin.id
  }

  tags = var.tags
}

# Alert 2: PostgreSQL Storage High
resource "azurerm_monitor_metric_alert" "pg_storage_high" {
  name                = "alert-pg-storage-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.primary_postgres_id]
  description         = "Triggers when Primary PostgreSQL storage usage exceeds 85%."
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.admin.id
  }

  tags = var.tags
}

# Alert 3: WAF Blocks High
resource "azurerm_monitor_metric_alert" "waf_blocks" {
  name                = "alert-waf-blocks"
  resource_group_name = var.resource_group_name
  scopes              = [var.primary_appgw_id]
  description         = "Triggers when WAF blocks more than 100 requests in 5 minutes."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "AzwafSecRule"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.admin.id
  }

  tags = var.tags
}

# Alert 4: Application Gateway 5xx Responses
resource "azurerm_monitor_metric_alert" "appgw_5xx" {
  name                = "alert-appgw-5xx"
  resource_group_name = var.resource_group_name
  scopes              = [var.primary_appgw_id]
  description         = "Triggers when App Gateway returns more than 10 5xx status codes in 5 minutes."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "ResponseStatus"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10

    dimension {
      name     = "HttpStatusGroup"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.admin.id
  }

  tags = var.tags
}


# Alert 6: Primary region down (Triggers Failover Runbook)
resource "azurerm_monitor_metric_alert" "primary_down" {
  count               = var.enable_frontdoor ? 1 : 0
  name                = "alert-primary-down"
  resource_group_name = var.resource_group_name
  scopes              = [var.frontdoor_profile_id]
  description         = "Triggers DR failover when Front Door Health Probe for India falls below 50% for 2 minutes."
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Cdn/profiles"
    metric_name      = "OriginHealthPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 50

    dimension {
      name     = "OriginName"
      operator = "Include"
      values   = ["origin-india"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr.id
  }

  tags = var.tags
}

# -------------------------------------------------------------
# Diagnostic Settings
# -------------------------------------------------------------

locals {
  # Build a diagnostic map with static keys known at plan time
  diagnostics_map = merge(
    {
      pg_india  = var.primary_postgres_id
      gw_india  = var.primary_appgw_id
      kv_india  = var.primary_keyvault_id
      sb_india  = var.primary_servicebus_id
      cae_india = var.primary_container_apps_env_id
      fn_india  = var.primary_function_app_id
    },
    var.enable_dr ? {
      pg_sea    = var.replica_postgres_id
      gw_sea    = var.replica_appgw_id
      kv_sea    = var.replica_keyvault_id
      sb_sea    = var.replica_servicebus_id
      cae_sea   = var.replica_container_apps_env_id
      fn_sea    = var.replica_function_app_id
    } : {},
    var.enable_frontdoor ? { frontdoor = var.frontdoor_profile_id } : {}
  )
}

resource "azurerm_monitor_diagnostic_setting" "diag" {
  for_each                   = local.diagnostics_map
  name                       = "diag-clahan-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_metric {
    category = "AllMetrics"
  }

  # For Front Door specific access logs:
  dynamic "enabled_log" {
    for_each = each.key == "frontdoor" ? ["FrontDoorAccessLog", "FrontDoorHealthProbeLog"] : []
    content {
      category = enabled_log.value
    }
  }

  # For App Gateways firewall logs:
  dynamic "enabled_log" {
    for_each = (each.key == "gw_india" || each.key == "gw_sea") ? ["ApplicationGatewayAccessLog", "ApplicationGatewayFirewallLog"] : []
    content {
      category = enabled_log.value
    }
  }
}

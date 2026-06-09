# Public IP for Application Gateway
resource "azurerm_public_ip" "pip" {
  name                = "pip-appgw-clahan-${var.region_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "pip-clahan-${var.region_short}-${var.random_suffix}"
  zones               = ["1", "2", "3"]

  tags = var.tags
}

# Web Application Firewall (WAF) Policy
resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "wafpol-clahan-${var.region_short}"
  resource_group_name = var.resource_group_name
  location            = var.location

  policy_settings {
    enabled = var.enable_waf
    mode    = "Prevention"
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
    }
  }

  tags = var.tags
}

# Application Gateway (WAF_v2)
resource "azurerm_application_gateway" "appgw" {
  name                = var.appgw_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  autoscale_configuration {
    min_capacity = var.appgw_capacity
    max_capacity = var.appgw_capacity + 8
  }

  gateway_ip_configuration {
    name      = "gw-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  backend_address_pool {
    name  = "backend-pool"
    fqdns = [var.backend_fqdn]
  }

  backend_http_settings {
    name                                = "http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "health-probe"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
    firewall_policy_id             = azurerm_web_application_firewall_policy.waf.id
  }

  request_routing_rule {
    name                       = "routing-rule-basic"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }

  probe {
    name                                      = "health-probe"
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  tags = var.tags
}

# modules/appgw/main.tf
# Azure Application Gateway v2 with WAF and SSL Termination using Key Vault certificates

locals {
  backend_address_pool_name       = "aks-backend-pool"
  frontend_port_name              = "appgw-frontend-port-http"
  frontend_port_https_name        = "appgw-frontend-port-https"
  frontend_ip_configuration_name  = "appgw-frontend-ip"
  http_setting_name               = "appgw-backend-http-setting"
  listener_name                   = "appgw-http-listener"
  listener_https_name             = "appgw-https-listener"
  request_routing_rule_name       = "appgw-routing-rule-http"
  request_routing_rule_https_name = "appgw-routing-rule-https"
  redirect_configuration_name     = "appgw-redirect-config"
  tags = merge(var.tags, {
    module = "appgw"
  })
}

# User Assigned Managed Identity for App Gateway to access Key Vault
resource "azurerm_user_assigned_identity" "appgw" {
  name                = "mi-appgw-clahan"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}

# Role Assignment to let App Gateway read secrets/certificates from Key Vault
resource "azurerm_role_assignment" "appgw_kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.appgw.principal_id
}

# Generate self-signed SSL certificate inside Key Vault for the custom domain
resource "azurerm_key_vault_certificate" "ssl_cert" {
  name         = "clahan-ssl-cert"
  key_vault_id = var.key_vault_id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # Server Auth
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
        "nonRepudiation",
        "digitalSignature"
      ]
      subject            = "CN=${var.domain_name}"
      validity_in_months = 12
    }
  }
}

# Public IP for the Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# WAF Policy with OWASP 3.2 protection
resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "waf-policy-clahan"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags

  policy_settings {
    enabled            = true
    mode               = "Prevention"
    request_body_check = true
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "appgw-clahan-academy"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.subnet_appgw_id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_port {
    name = local.frontend_port_https_name
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  ssl_certificate {
    name                = "clahan-ssl-cert"
    key_vault_secret_id = azurerm_key_vault_certificate.ssl_cert.secret_id
  }

  backend_address_pool {
    name         = local.backend_address_pool_name
    ip_addresses = ["10.0.4.100"] # Default internal IP for the ingress/gateway load balancer
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  # HTTP listener
  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  # HTTPS listener with SSL cert
  http_listener {
    name                           = local.listener_https_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_https_name
    protocol                       = "Https"
    ssl_certificate_name           = "clahan-ssl-cert"
  }

  # Redirect HTTP to HTTPS
  redirect_configuration {
    name                 = local.redirect_configuration_name
    redirect_type        = "Permanent"
    target_listener_name = local.listener_https_name
    include_path         = true
    include_query_string = true
  }

  # HTTP routing rule (triggers redirect)
  request_routing_rule {
    name                        = local.request_routing_rule_name
    rule_type                   = "Basic"
    http_listener_name          = local.listener_name
    redirect_configuration_name = local.redirect_configuration_name
    priority                    = 100
  }

  # HTTPS routing rule (sends traffic to backend)
  request_routing_rule {
    name                       = local.request_routing_rule_https_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_https_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 101
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.waf.id

  depends_on = [
    azurerm_role_assignment.appgw_kv_secrets_user
  ]
}

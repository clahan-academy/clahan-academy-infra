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

# Azure AD role assignment propagation is eventually-consistent: ARM reports
# the assignment as "succeeded" well before Key Vault's data plane actually
# honors it. depends_on alone only waits for the ARM write, not propagation,
# so a freshly created mi-appgw-clahan identity can fail its first SSL
# certificate fetch and leave the HTTPS listener stuck (root cause of the
# Bad Gateway recurring after every transient destroy/apply cycle).
resource "time_sleep" "wait_for_appgw_kv_rbac" {
  depends_on      = [azurerm_role_assignment.appgw_kv_secrets_user]
  create_duration = "120s"
}

# WAF Policy with OWASP 3.2 protection
resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "waf-policy-clahan"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags

  policy_settings {
    enabled            = true
    mode               = "Detection"
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
    public_ip_address_id = var.public_ip_id
  }

  ssl_certificate {
    name                = "clahan-ssl-cert"
    key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/clahan-ssl-cert"
  }

  backend_address_pool {
    name         = local.backend_address_pool_name
    ip_addresses = ["10.0.4.250"] # Default internal IP for the ingress/gateway load balancer
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    # Raised from 60s: the exam-service AI generation endpoints (Ollama LLM
    # inference) routinely exceeded 60s, producing 504 Gateway Timeout.
    # This is one global backend setting for all traffic, but a higher
    # ceiling doesn't slow down fast endpoints - it's just the max AppGW
    # will wait before giving up.
    request_timeout       = 180
    probe_name            = "appgw-health-probe"
  }

  probe {
    name                                      = "appgw-health-probe"
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    host                                      = var.domain_name
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
    time_sleep.wait_for_appgw_kv_rbac
  ]
}

# Self-heal: force Application Gateway to re-fetch the Key Vault certificate
# on every apply, retrying with backoff instead of trusting a single fixed
# sleep. No Azure-documented SLA exists for RBAC propagation, so a static
# wait is always a guess - this keeps nudging the gateway until the cert is
# actually bound (confirmed via provisioningState, not just a 200 from the
# update call) or gives up loudly after a real timeout. This replaces the
# manual request-ssl.ps1 "ssl-cert update" step that used to require a human
# to notice the gateway was stuck and re-run it by hand.
resource "null_resource" "refresh_ssl_cert" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -uo pipefail
      RG="${var.resource_group_name}"
      GW="${azurerm_application_gateway.main.name}"
      SECRET_ID="https://${var.key_vault_name}.vault.azure.net/secrets/clahan-ssl-cert"
      ATTEMPTS=20
      SLEEP_SECS=15

      for i in $(seq 1 $ATTEMPTS); do
        if az network application-gateway ssl-cert update \
            -g "$RG" --gateway-name "$GW" -n clahan-ssl-cert \
            --key-vault-secret-id "$SECRET_ID" >/tmp/sslcert_update_$$.log 2>&1; then
          STATE=$(az network application-gateway show -g "$RG" -n "$GW" --query "provisioningState" -o tsv 2>/dev/null || echo "")
          if [ "$STATE" == "Succeeded" ]; then
            echo "SSL certificate bound successfully on attempt $i/$ATTEMPTS"
            exit 0
          fi
          echo "Attempt $i/$ATTEMPTS: update accepted but provisioningState=$STATE, retrying in $${SLEEP_SECS}s..."
        else
          echo "Attempt $i/$ATTEMPTS: ssl-cert update command failed, retrying in $${SLEEP_SECS}s..."
          cat /tmp/sslcert_update_$$.log
        fi
        sleep $SLEEP_SECS
      done

      echo "ERROR: SSL certificate still not bound after $((ATTEMPTS * SLEEP_SECS))s."
      echo "This has exceeded the typical Azure AD RBAC propagation window - it is"
      echo "likely a real misconfiguration (role scope/principal, Key Vault firewall),"
      echo "not a propagation delay. Check appgw_kv_secrets_user manually."
      exit 1
    EOT
  }

  depends_on = [azurerm_application_gateway.main]
}

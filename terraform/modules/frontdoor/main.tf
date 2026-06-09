# Azure Front Door Profile
resource "azurerm_cdn_frontdoor_profile" "profile" {
  name                = var.profile_name
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

# Azure Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = "ep-clahan-global-${var.random_suffix}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id
  tags                     = var.tags
}

# Front Door Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "og" {
  name                     = "og-clahan"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.profile.id

  session_affinity_enabled = false

  health_probe {
    path                = "/"
    protocol            = "Http"
    interval_in_seconds = 30
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 2
  }
}

# Front Door Origins (Primary / Active)
resource "azurerm_cdn_frontdoor_origin" "origin_india" {
  name                          = "origin-india"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id
  host_name                     = var.primary_appgw_fqdn
  http_port                     = 80
  https_port                    = 443
  origin_host_header            = var.primary_appgw_fqdn
  priority                      = 1
  weight                        = 1000
  enabled                       = true
  certificate_name_check_enabled = false
}

# Front Door Origins (Secondary / Standby)
resource "azurerm_cdn_frontdoor_origin" "origin_sea" {
  name                          = "origin-sea"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id
  host_name                     = var.secondary_appgw_fqdn
  http_port                     = 80
  https_port                    = 443
  origin_host_header            = var.secondary_appgw_fqdn
  priority                      = 2
  weight                        = 1000
  enabled                       = true
  certificate_name_check_enabled = false
}

# Front Door Routing Rule
resource "azurerm_cdn_frontdoor_route" "route" {
  name                          = "route-clahan"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id
  cdn_frontdoor_origin_ids      = [
    azurerm_cdn_frontdoor_origin.origin_india.id,
    azurerm_cdn_frontdoor_origin.origin_sea.id
  ]

  forwarding_protocol    = "HttpOnly" # demo only (no SSL)
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  link_to_default_domain = true

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
  }
}

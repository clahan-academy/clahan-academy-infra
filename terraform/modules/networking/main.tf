# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "snet_appgw" {
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.snet_appgw_cidr]
}

resource "azurerm_subnet" "snet_containerapp" {
  name                 = "snet-containerapp"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.snet_containerapp_cidr]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "snet_data" {
  name                 = "snet-data"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.snet_data_cidr]
}

resource "azurerm_subnet" "snet_function" {
  name                 = "snet-function"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.snet_function_cidr]

  delegation {
    name = "func-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Network Security Groups
resource "azurerm_network_security_group" "nsg_appgw" {
  name                = "nsg-clahan-${var.region_short}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_containerapp" {
  name                = "nsg-clahan-${var.region_short}-containerapp"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowAppGwInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.snet_appgw_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_data" {
  name                = "nsg-clahan-${var.region_short}-data"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowPostgresFromContainerApp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.snet_containerapp_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRedisFromContainerApp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["6379", "10000"]
    source_address_prefix      = var.snet_containerapp_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSFromContainerApp"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.snet_containerapp_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_function" {
  name                = "nsg-clahan-${var.region_short}-function"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "AllowOutboundToData"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5432", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = var.snet_data_cidr
  }
}

# Subnet-NSG Associations
resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.snet_appgw.id
  network_security_group_id = azurerm_network_security_group.nsg_appgw.id
}

resource "azurerm_subnet_network_security_group_association" "containerapp" {
  subnet_id                 = azurerm_subnet.snet_containerapp.id
  network_security_group_id = azurerm_network_security_group.nsg_containerapp.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.snet_data.id
  network_security_group_id = azurerm_network_security_group.nsg_data.id
}

resource "azurerm_subnet_network_security_group_association" "function" {
  subnet_id                 = azurerm_subnet.snet_function.id
  network_security_group_id = azurerm_network_security_group.nsg_function.id
}

# Private DNS Zones
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "servicebus" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# DNS Zone Links to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "link-postgres-${var.region_short}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "link-redis-${var.region_short}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                  = "link-vault-${var.region_short}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  name                  = "link-servicebus-${var.region_short}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags                  = var.tags
}

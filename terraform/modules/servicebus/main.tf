# Azure Service Bus Namespace
resource "azurerm_servicebus_namespace" "sb" {
  name                          = var.namespace_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = 1
  premium_messaging_partitions  = 1
  public_network_access_enabled = false

  tags = var.tags
}

# Service Bus Topics
resource "azurerm_servicebus_topic" "exam_events" {
  name         = "exam-events"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_servicebus_topic" "notification_events" {
  name         = "notification-events"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_servicebus_topic" "proctoring_events" {
  name         = "proctoring-events"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

# Service Bus Subscriptions
resource "azurerm_servicebus_subscription" "exam_processor" {
  name               = "sub-exam-processor"
  topic_id           = azurerm_servicebus_topic.exam_events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "exam_notification" {
  name               = "sub-notification"
  topic_id           = azurerm_servicebus_topic.exam_events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "email_sender" {
  name               = "sub-email-sender"
  topic_id           = azurerm_servicebus_topic.notification_events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "ai_analyzer" {
  name               = "sub-ai-analyzer"
  topic_id           = azurerm_servicebus_topic.proctoring_events.id
  max_delivery_count = 10
}

# Private Endpoint for Service Bus
resource "azurerm_private_endpoint" "sb_pe" {
  name                = "pe-${var.namespace_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-${var.namespace_name}"
    private_connection_resource_id = azurerm_servicebus_namespace.sb.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "dns-group-sb"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

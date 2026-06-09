variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region for Service Bus."
}

variable "namespace_name" {
  type        = string
  description = "The name of the Service Bus namespace."
}

variable "sku" {
  type        = string
  description = "SKU for Service Bus (Premium is required for private endpoints)."
  default     = "Premium"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for private endpoint."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS Zone ID for Service Bus."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

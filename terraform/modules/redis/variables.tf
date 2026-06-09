variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region for Redis."
}

variable "redis_name" {
  type        = string
  description = "The name of the Redis instance."
}

variable "sku_name" {
  type        = string
  description = "The SKU for Redis."
  default     = "Standard"
}

variable "family" {
  type        = string
  description = "The SKU family."
  default     = "C"
}

variable "capacity" {
  type        = number
  description = "The size of the Redis cache."
  default     = 1
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for private endpoint."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS Zone ID for Redis."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

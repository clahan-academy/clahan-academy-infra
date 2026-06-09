variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region to deploy Container Apps."
}

variable "environment" {
  type        = string
  description = "The environment name (dev, staging, or prod)."
}

variable "region_short" {
  type        = string
  description = "Short name of the region (india or sea)."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for container app environment injection."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "The shared Log Analytics Workspace ID."
}

variable "container_apps_map" {
  type = map(object({
    image        = string
    port         = number
    cpu          = number
    memory       = string
    max_replicas = number
    external     = optional(bool, false)
    command      = optional(list(string), null)
    args         = optional(list(string), null)
    env          = optional(map(string), {})
  }))
  description = "Configuration details for each container app."
}

variable "container_apps_min_replicas" {
  type        = number
  description = "The minimum number of replicas for Container Apps in the active region."
}

variable "postgres_connection_string_secret_id" {
  type        = string
  description = "The Key Vault secret ID for PostgreSQL connection string."
}

variable "redis_connection_string_secret_id" {
  type        = string
  description = "The Key Vault secret ID for Redis connection string."
}

variable "servicebus_connection_string_secret_id" {
  type        = string
  description = "The Key Vault secret ID for Service Bus connection string."
}

variable "smtp_password_secret_id" {
  type        = string
  description = "The Key Vault secret ID for SMTP password."
}

variable "key_vault_id" {
  type        = string
  description = "The Key Vault resource ID."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

variable "vnet_id" {
  type        = string
  description = "The virtual network ID to link the Private DNS Zone to."
}

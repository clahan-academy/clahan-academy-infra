variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region for the Function App."
}

variable "environment" {
  type        = string
  description = "The environment name (dev, staging, or prod)."
}

variable "region_short" {
  type        = string
  description = "Short name of the region."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID of snet-function for VNet integration."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace ID."
}

variable "postgres_connection_string_secret_id" {
  type        = string
  description = "Key Vault Secret ID of the PostgreSQL connection string."
}

variable "random_suffix" {
  type        = string
  description = "Random suffix for globally-unique naming."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

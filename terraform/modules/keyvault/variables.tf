variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region to deploy Key Vault."
}

variable "environment" {
  type        = string
  description = "The environment name (dev, staging, or prod)."
}

variable "region_short" {
  type        = string
  description = "Short name of the region."
}

variable "random_suffix" {
  type        = string
  description = "Random 4-character suffix for globally-unique naming."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint (snet-data)."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS Zone ID for Key Vault (privatelink.vaultcore.azure.net)."
}

variable "tenant_id" {
  type        = string
  description = "The tenant ID."
}

variable "secrets" {
  type        = map(string)
  description = "A map of secrets to write to the Key Vault."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

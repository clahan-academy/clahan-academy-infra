variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region to deploy networking resources."
}

variable "vnet_name" {
  type        = string
  description = "The name of the Virtual Network."
}

variable "vnet_address_space" {
  type        = list(string)
  description = "The address space for the VNet."
}

variable "region_short" {
  type        = string
  description = "Short name of the region (india or sea)."
}

variable "snet_appgw_cidr" {
  type        = string
  description = "CIDR block for Application Gateway subnet."
}

variable "snet_containerapp_cidr" {
  type        = string
  description = "CIDR block for Container Apps infrastructure subnet."
}

variable "snet_data_cidr" {
  type        = string
  description = "CIDR block for database / data private endpoint subnet."
}

variable "snet_function_cidr" {
  type        = string
  description = "CIDR block for Azure Functions delegation subnet."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

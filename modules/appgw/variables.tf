# modules/appgw/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subnet_appgw_id" {
  description = "Subnet ID of the Application Gateway subnet"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Azure Key Vault"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for SSL certificate"
  type        = string
  default     = "clahaanacademy.online"
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

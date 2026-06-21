# terraform/modules/networking/variables.tf

variable "resource_group_name" {
  description = "Name of the Azure resource group to create"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_bastion" {
  description = "Enable Azure Bastion host for secure VM access"
  type        = bool
  default     = true
}

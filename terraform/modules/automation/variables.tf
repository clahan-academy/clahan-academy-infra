variable "resource_group_name" {
  type        = string
  description = "The name of the shared global resource group."
}

variable "location" {
  type        = string
  description = "The Azure region for the Automation Account."
}

variable "automation_account_name" {
  type        = string
  description = "The name of the Automation Account."
  default     = "aa-clahan-global"
}

variable "primary_rg_id" {
  type        = string
  description = "The resource ID of the primary resource group."
}

variable "dr_rg_id" {
  type        = string
  description = "The resource ID of the DR resource group."
}

variable "environment" {
  type        = string
  description = "The environment name (dev, staging, or prod)."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

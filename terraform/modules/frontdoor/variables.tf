variable "resource_group_name" {
  type        = string
  description = "The name of the shared global resource group."
}

variable "profile_name" {
  type        = string
  description = "The name of the Front Door profile."
  default     = "afd-clahan-global"
}

variable "primary_appgw_fqdn" {
  type        = string
  description = "The FQDN of the Primary Application Gateway."
}

variable "secondary_appgw_fqdn" {
  type        = string
  description = "The FQDN of the Secondary (DR) Application Gateway."
}

variable "random_suffix" {
  type        = string
  description = "Random 4-character suffix for global endpoint uniqueness."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

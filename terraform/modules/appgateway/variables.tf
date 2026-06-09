variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region for the App Gateway."
}

variable "region_short" {
  type        = string
  description = "Short name of the region (india or sea)."
}

variable "appgw_name" {
  type        = string
  description = "The name of the Application Gateway."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID of snet-appgw."
}

variable "backend_fqdn" {
  type        = string
  description = "FQDN of the container app to route traffic to (e.g. frontend-service FQDN)."
}

variable "random_suffix" {
  type        = string
  description = "Random suffix for unique public IP DNS labeling."
}

variable "appgw_capacity" {
  type        = number
  description = "The minimum autoscale capacity of the Application Gateway."
  default     = 2
}

variable "enable_waf" {
  type        = bool
  description = "Flag to enable Web Application Firewall policy."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

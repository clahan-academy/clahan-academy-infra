# terraform/modules/postgres/variables.tf

variable "resource_group_name" {
  type = string
}
variable "location" {
  type    = string
  default = "eastus2"
}

variable "sku_name" {
  type    = string
  default = "GP_Standard_D2s_v3"
}
variable "storage_mb" {
  type    = number
  default = 32768
}
variable "backup_retention_days" {
  type    = number
  default = 7
}
variable "geo_redundant_backup_enabled" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for PostgreSQL Flexible Server"
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS Zone ID for PostgreSQL Flexible Server"
  type        = string
}
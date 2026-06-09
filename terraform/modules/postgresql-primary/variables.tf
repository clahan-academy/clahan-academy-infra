variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region for the primary database."
}

variable "server_name" {
  type        = string
  description = "The name of the PostgreSQL server."
}

variable "admin_username" {
  type        = string
  description = "The administrator login name."
  default     = "pgadmin"
}

variable "admin_password" {
  type        = string
  description = "The administrator login password."
  sensitive   = true
}

variable "sku_name" {
  type        = string
  description = "The SKU name for the PostgreSQL server."
  default     = "GP_Standard_D4s_v3"
}

variable "storage_mb" {
  type        = number
  description = "Max storage allowed for the server in MB."
  default     = 131072 # 128 GB
}

variable "backup_retention_days" {
  type        = number
  description = "Backup retention days."
  default     = 35
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for private endpoint."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS Zone ID for PostgreSQL."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

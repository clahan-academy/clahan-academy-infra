variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "location" {
  type        = string
  description = "The Azure region for the replica database."
}

variable "server_name" {
  type        = string
  description = "The name of the replica PostgreSQL server."
}

variable "primary_server_id" {
  type        = string
  description = "The resource ID of the primary PostgreSQL server."
}

variable "sku_name" {
  type        = string
  description = "The SKU name for the PostgreSQL server (must match primary)."
  default     = "GP_Standard_D4s_v3"
}

variable "storage_mb" {
  type        = number
  description = "Max storage allowed for the server in MB (must match or exceed primary)."
  default     = 131072 # 128 GB
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

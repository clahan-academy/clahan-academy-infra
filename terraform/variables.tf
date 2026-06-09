variable "project_name" {
  type        = string
  description = "The name of the project."
  default     = "clahan"
}

variable "environment" {
  type        = string
  description = "The environment name (dev, staging, or prod)."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  type        = string
  description = "The owner of the resources."
}

variable "admin_email" {
  type        = string
  description = "The email address of the administrator for notifications."
}

variable "primary_location" {
  type        = string
  description = "The primary Azure region."
  default     = "centralindia"
}

variable "dr_location" {
  type        = string
  description = "The disaster recovery Azure region."
  default     = "southeastasia"
}

variable "enable_dr" {
  type        = bool
  description = "Flag to enable Disaster Recovery region deployment."
  default     = false
}

variable "enable_waf" {
  type        = bool
  description = "Flag to enable WAF on the Application Gateway."
  default     = false
}

variable "postgres_sku" {
  type        = string
  description = "The SKU for the PostgreSQL flexible server (e.g. GP_Standard_D2s_v3)."
}

variable "postgres_storage_mb" {
  type        = number
  description = "The storage size in MB for the PostgreSQL server."
}

variable "redis_sku" {
  type        = string
  description = "The SKU for the Redis Cache (Basic, Standard, or Premium)."
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku)
    error_message = "The redis_sku must be one of: Basic, Standard, Premium."
  }
}

variable "redis_family" {
  type        = string
  description = "The SKU family for Redis (usually C or P)."
  default     = "C"
}

variable "redis_capacity" {
  type        = number
  description = "The capacity/size for Redis Cache (0-6 depending on SKU)."
}

variable "appgw_capacity" {
  type        = number
  description = "The capacity for the Application Gateway WAF_v2 SKU."
  default     = 2
}

variable "container_apps_min_replicas" {
  type        = number
  description = "The minimum number of replicas for Container Apps."
}

variable "container_apps_max_replicas" {
  type        = number
  description = "The maximum number of replicas for Container Apps."
}

variable "smtp_host" {
  type        = string
  description = "The SMTP server host."
}

variable "smtp_port" {
  type        = string
  description = "The SMTP server port."
}

variable "smtp_password" {
  type        = string
  description = "The SMTP server password."
  sensitive   = true
  default     = "changeme"
}

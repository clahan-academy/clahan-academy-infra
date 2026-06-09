variable "resource_group_name" {
  type        = string
  description = "The name of the shared global resource group."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "The Resource ID of the shared Log Analytics Workspace."
}

variable "location" {
  type        = string
  description = "The Azure region for monitoring resources."
}

variable "admin_email" {
  type        = string
  description = "The administrator email for notifications."
}

variable "frontdoor_profile_id" {
  type        = string
  description = "Front Door profile resource ID."
  default     = ""
}

variable "automation_account_id" {
  type        = string
  description = "Automation account ID."
}

variable "runbook_failover_name" {
  type        = string
  description = "Failover runbook name."
}

variable "failover_webhook_id" {
  type        = string
  description = "Automation Webhook resource ID."
}

variable "failover_webhook_uri" {
  type        = string
  description = "Automation Webhook service URI."
}

variable "primary_postgres_id" {
  type        = string
  description = "Primary PostgreSQL server ID."
}

variable "replica_postgres_id" {
  type        = string
  description = "Replica PostgreSQL server ID."
  default     = ""
}

variable "primary_appgw_id" {
  type        = string
  description = "Primary App Gateway ID."
}

variable "replica_appgw_id" {
  type        = string
  description = "DR App Gateway ID."
  default     = ""
}

variable "primary_keyvault_id" {
  type        = string
  description = "Primary Key Vault ID."
}

variable "replica_keyvault_id" {
  type        = string
  description = "DR Key Vault ID."
  default     = ""
}

variable "primary_servicebus_id" {
  type        = string
  description = "Primary Service Bus namespace ID."
}

variable "replica_servicebus_id" {
  type        = string
  description = "DR Service Bus namespace ID."
  default     = ""
}

variable "primary_container_apps_env_id" {
  type        = string
  description = "Primary Container Apps Environment ID."
}

variable "replica_container_apps_env_id" {
  type        = string
  description = "DR Container Apps Environment ID."
  default     = ""
}

variable "primary_function_app_id" {
  type        = string
  description = "Primary Function App ID."
}

variable "replica_function_app_id" {
  type        = string
  description = "DR Function App ID."
  default     = ""
}

variable "enable_dr" {
  type        = bool
  description = "Whether Disaster Recovery resources are enabled."
  default     = false
}

variable "enable_frontdoor" {
  type        = bool
  description = "Whether Front Door monitoring should be enabled."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Resource tags."
}

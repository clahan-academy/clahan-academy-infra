# terraform/modules/keyvault/variables.tf

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "tenant_id" {
  type = string
}

variable "deployer_object_id" {
  type = string
}

variable "github_sp_object_id" {
  type = string
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = "kv-clahan-dev"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "secrets" {
  description = "Sensitive secrets to store in Key Vault"
  sensitive   = true
  type = object({
    blob_storage_account = string
    blob_storage_key     = string
  })
}
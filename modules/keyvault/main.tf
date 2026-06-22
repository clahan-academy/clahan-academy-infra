# terraform/modules/keyvault/main.tf
# Azure Key Vault - central secret store for all application secrets

locals {
  tags = merge(var.tags, {
    module = "keyvault"
  })
}

# Key Vault with RBAC authorization
resource "azurerm_key_vault" "main" {
  name                          = var.key_vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = "standard"
  tenant_id                     = var.tenant_id
  enable_rbac_authorization     = true
  soft_delete_retention_days    = 90
  purge_protection_enabled      = true
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
    ip_rules       = []
  }

  tags = local.tags
}

# Deployer gets Secrets Officer (deployer is a User not SP)
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  name                 = uuidv5("dns", "${var.deployer_object_id}-kv-admin-${azurerm_key_vault.main.name}")
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.deployer_object_id
  scope                = azurerm_key_vault.main.id
}

# GitHub Actions gets Secrets User
resource "azurerm_role_assignment" "github_secrets_user" {
  name                             = uuidv5("dns", "${var.github_sp_object_id}-kv-user-${azurerm_key_vault.main.name}")
  role_definition_name             = "Key Vault Administrator"
  principal_id                     = var.github_sp_object_id
  scope                            = azurerm_key_vault.main.id
  skip_service_principal_aad_check = true
}

# Wait 240 seconds for RBAC to propagate before writing secrets
resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.deployer_secrets_officer,
    azurerm_role_assignment.github_secrets_user
  ]
  create_duration = "240s"
}

# Auto-generate JWT secrets
resource "random_password" "jwt_access" {
  length           = 64
  special          = true
  override_special = "!#$%&*-_=+?"
  min_lower        = 8
  min_upper        = 8
  min_numeric      = 8
  min_special      = 4
}

resource "random_password" "jwt_refresh" {
  length           = 64
  special          = true
  override_special = "!#$%&*-_=+?"
  min_lower        = 8
  min_upper        = 8
  min_numeric      = 8
  min_special      = 4
}

# SENSITIVE SECRETS - Never move to ConfigMap

resource "azurerm_key_vault_secret" "jwt_access_secret" {
  name         = "jwt-access-secret"
  value        = random_password.jwt_access.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "jwt_refresh_secret" {
  name         = "jwt-refresh-secret"
  value        = random_password.jwt_refresh.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "smtp_host" {
  name         = "smtp-host"
  value        = var.secrets.smtp_host
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "smtp_port" {
  name         = "smtp-port"
  value        = var.secrets.smtp_port
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "smtp_user" {
  name         = "smtp-user"
  value        = var.secrets.smtp_user
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "smtp_pass" {
  name         = "smtp-pass"
  value        = var.secrets.smtp_pass
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "smtp_from" {
  name         = "smtp-from"
  value        = var.secrets.smtp_from
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "sendgrid_api_key" {
  name         = "sendgrid-api-key"
  value        = var.secrets.sendgrid_api_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "sendgrid_from" {
  name         = "sendgrid-from"
  value        = var.secrets.sendgrid_from
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "blob_storage_account" {
  name         = "blob-storage-account"
  value        = var.secrets.blob_storage_account
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "blob_storage_key" {
  name         = "blob-storage-key"
  value        = var.secrets.blob_storage_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "snyk_token" {
  name         = "snyk-token"
  value        = var.secrets.snyk_token
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "sonar_token" {
  name         = "sonar-token"
  value        = var.secrets.sonar_token
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

# NON-SENSITIVE - Can be moved to ConfigMap later
resource "azurerm_key_vault_secret" "frontend_url" {
  name         = "frontend-url"
  value        = "https://clahaanacademy.online"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "ai_service_url" {
  name         = "ai-service-url"
  value        = "http://ai-service.clahan-academy.svc.cluster.local:8000"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "ollama_url" {
  name         = "ollama-url"
  value        = "http://ollama.clahan-academy.svc.cluster.local:11434"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "judge0_url" {
  name         = "judge0-url"
  value        = "http://judge0-api.clahan-academy.svc.cluster.local:2358"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "node_env" {
  name         = "node-env"
  value        = "production"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

# Port & limit secrets expected by Helm SecretProviderClasses
resource "azurerm_key_vault_secret" "admin_port" {
  name         = "admin-port"
  value        = "4002"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "auth_port" {
  name         = "auth-port"
  value        = "4001"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "student_port" {
  name         = "student-port"
  value        = "4003"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "exam_port" {
  name         = "exam-port"
  value        = "4004"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "proctoring_port" {
  name         = "proctoring-port"
  value        = "4005"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "notification_port" {
  name         = "notification-port"
  value        = "4006"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "ai_port" {
  name         = "ai-port"
  value        = "8000"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "rate_limit_max" {
  name         = "rate-limit-max"
  value        = "100"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "tab_switch_limit" {
  name         = "tab-switch-limit"
  value        = "3"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "mobile_phone_limit" {
  name         = "mobile-phone-limit"
  value        = "1"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "book_limit" {
  name         = "book-limit"
  value        = "1"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "multiple_faces_limit" {
  name         = "multiple-faces-limit"
  value        = "2"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "no_face_timeout_ms" {
  name         = "no-face-timeout-ms"
  value        = "5000"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}

resource "azurerm_key_vault_secret" "fullscreen_exit_limit" {
  name         = "fullscreen-exit-limit"
  value        = "3"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = local.tags
  depends_on   = [time_sleep.wait_for_rbac]
}
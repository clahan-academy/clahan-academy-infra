# ================================================================
# DEVELOPMENT Environment Variables
# ================================================================

environment         = "dev"
resource_group_name = "rg-clahan-dev"
location            = "eastus2"

# Azure Identity (from bootstrap output)
subscription_id      = "65bf2554-8090-4538-9c38-8a6e9c5f6f22"
tenant_id            = "d8537334-bc24-4daf-95a8-bf4c9fb14394"
github_app_client_id = "c3865c88-93a4-4643-8bfd-ab0378daf87c"
github_sp_object_id  = "689433c3-9091-4ab5-b99a-ff1bd8e933a7"
deployer_object_id   = "27378415-08cd-441e-857a-763364f8459a"

# Admin
admin_email = "admin@clahaanacademy.online"

# SMTP (Replace with your SMTP/Gmail configurations)
smtp_host = "smtp.gmail.com"
smtp_port = "587"
smtp_user = "YOUR_GMAIL_USERNAME@gmail.com"
smtp_pass = "YOUR_GMAIL_APP_PASSWORD"
smtp_from = "YOUR_GMAIL_USERNAME@gmail.com"

# Security tokens (Replace with your Snyk and Sonar tokens)
snyk_token  = "YOUR_SNYK_TOKEN"
sonar_token = "5c7418c03235a4fa41706224d3c075c4e9c425a7" # Automatically pre-filled with your new token

# Key Vault (globally unique name)
key_vault_name = "kv-clahan-65bf2554"

# AKS DEV sizing (minimal)
app_node_vm_size = "Standard_D2s_v3"
app_node_count   = 1
app_min_count    = 1
app_max_count    = 3

# PostgreSQL DEV
postgres_sku           = "GP_Standard_D2s_v3"
postgres_storage_mb    = 32768
postgres_backup_days   = 7
postgres_geo_redundant = false

# Redis DEV
redis_capacity = 1

# Functions DEV
enable_functions = true

# Jump VM + Bastion DEV (disabled to save cost, use az aks command invoke)
enable_jumpvm = false

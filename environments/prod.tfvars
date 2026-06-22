# ================================================================
# PRODUCTION Environment Variables
# ================================================================

environment         = "prod"
resource_group_name = "rg-clahan-prod"
location            = "eastus2"

# Azure Identity (same subscription as dev)
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

# Security tokens
snyk_token  = "YOUR_SNYK_TOKEN"
sonar_token = "5c7418c03235a4fa41706224d3c075c4e9c425a7"

# Key Vault (globally unique name)
key_vault_name = "kv-clahan-prod"

# AKS PRODUCTION sizing
app_node_vm_size = "Standard_D4s_v3"
app_node_count   = 2
app_min_count    = 2
app_max_count    = 5

# PostgreSQL PRODUCTION
postgres_sku           = "GP_Standard_D4s_v3"
postgres_storage_mb    = 65536
postgres_backup_days   = 14
postgres_geo_redundant = true

# Redis PRODUCTION
redis_capacity = 2

# All modules enabled in production
enable_functions = true
enable_jumpvm    = true

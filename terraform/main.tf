# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "botvinnik-tf-rg"
    storage_account_name = "botvinniktfstac"
    container_name       = "botvinnik-tf-cont"
    key                  = "botvinnik-tf.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}
data "azurerm_client_config" "current" {}

# -----------

# Resource group
resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = var.region
}

# App plan
resource "azurerm_service_plan" "appplan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  sku_name            = var.app_service_plan_sku_name
  os_type             = "Linux"
}

# App service
resource "azurerm_linux_web_app" "app_service" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  service_plan_id     = azurerm_service_plan.appplan.id

  site_config {
    always_on = var.app_service_always_on

    application_stack {
      dotnet_version = "6.0"
    }
  }

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = var.aspnetcore_environment
  }

  identity {
    type = "SystemAssigned"
  }
}

# Create Key Vault
resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"
}

# Key Vault Access Policies
# This first policy is adding the permissions for the user Terraform is authenticated as
# to let him add, delete and update secrets in the Key Vault.
resource "azurerm_key_vault_access_policy" "service_principal_access_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Purge",
    "Set",
    "Delete"
  ]

  application_id          = null
  key_permissions         = null
  storage_permissions     = null
  certificate_permissions = null
}

# This policy is for the App Service (our application) to access secrets.
resource "azurerm_key_vault_access_policy" "app_service_access_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app_service.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
  ]

  application_id          = null
  key_permissions         = null
  storage_permissions     = null
  certificate_permissions = null
}

# We create a random password for the database
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# The secret that we want to add to the Key Vault
# Notice that we use the password created before
resource "azurerm_key_vault_secret" "db_password" {
  name         = "DbPassword"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.service_principal_access_policy
  ]
}

# SQL Server, we put as a password the one created before
# Notice how no user -not even us- knows the password
# The DB password is saved in a Key Vault so authorized applications
# can get it to connect to the database, without having the secret
# explicitally stated in their configuration.
resource "azurerm_sql_server" "sql_server" {
  name                         = var.db_server_name
  resource_group_name          = azurerm_resource_group.resource_group.name
  location                     = azurerm_resource_group.resource_group.location
  version                      = "12.0"
  administrator_login          = var.db_user
  administrator_login_password = random_password.db_password.result
}

resource "azurerm_sql_database" "sql_db" {
  name                = var.db_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  server_name         = azurerm_sql_server.sql_server.name
}
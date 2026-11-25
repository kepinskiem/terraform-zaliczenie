variable "env" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  type = string
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "data" {
  name     = "rg-ecommerce-${var.env}"
  location = var.location
}

resource "azurerm_storage_account" "data" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.data.name
  location                        = azurerm_resource_group.data.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_data_lake_gen2_filesystem" "layer" {
  for_each = toset(["bronze", "silver", "gold"])

  name               = each.key
  storage_account_id = azurerm_storage_account.data.id
}

resource "azurerm_key_vault" "data" {
  name                       = "kv-${var.storage_account_name}"
  resource_group_name        = azurerm_resource_group.data.name
  location                   = azurerm_resource_group.data.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = false
  soft_delete_retention_days = 7
  purge_protection_enabled   = var.env == "prod"
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id       = azurerm_key_vault.data.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Recover"]
}

resource "azurerm_key_vault_secret" "connection" {
  name         = "adls-connection-string"
  value        = azurerm_storage_account.data.primary_connection_string
  key_vault_id = azurerm_key_vault.data.id

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

output "adls_paths" {
  value = {
    for name in keys(azurerm_storage_data_lake_gen2_filesystem.layer) :
    name => "abfss://${name}@${azurerm_storage_account.data.name}.dfs.core.windows.net/"
  }
}

output "key_vault_uri" {
  value = azurerm_key_vault.data.vault_uri
}
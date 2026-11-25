terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "env" {
  type    = string
  default = "dev"
}

module "azure_datalake" {
  source = "../modules/azure_datalake"

  env                  = var.env
  location             = "westeurope"
  storage_account_name = "stecom${var.env}745041967631"
}

output "azure_adls_paths" {
  value = module.azure_datalake.adls_paths
}

output "azure_key_vault_uri" {
  value = module.azure_datalake.key_vault_uri
}
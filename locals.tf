locals {
  name_prefix = "ecommerce-${var.env}"

  env_config = {
    dev  = { deletion_protection = false }
    prod = { deletion_protection = true }
  }
}
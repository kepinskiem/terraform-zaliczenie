variable "env" {
  description = "Srodowisko projektu."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "Dozwolone srodowiska to dev i prod."
  }
}

variable "db_username" {
  description = "Nazwa uzytkownika administracyjnego PostgreSQL."
  type        = string
}

variable "db_password" {
  description = "Haslo uzytkownika administracyjnego PostgreSQL."
  type        = string
  sensitive   = true
}

variable "create_glue_job" {
  description = "Czy utworzyc job AWS Glue."
  type        = bool
  default     = true
}
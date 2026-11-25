terraform {
  backend "s3" {
    bucket         = "ecommerce-tf-state-745041967631-eu-north-1"
    key            = "ecommerce/dev/terraform.tfstate"
    region         = "eu-north-1"
    profile        = "ecommerce-dev"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-north-1"
  profile = "ecommerce-dev"
}

resource "aws_s3_bucket" "data" {
  for_each      = toset(["raw", "processed", "curated"])
  bucket_prefix = "ecommerce-dev-${each.key}-"
}
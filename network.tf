resource "aws_vpc" "rds" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ecommerce-dev-rds"
  }
}

resource "aws_subnet" "rds_private" {
  for_each = {
    "eu-north-1a" = "10.0.1.0/24"
    "eu-north-1c" = "10.0.2.0/24"
  }

  vpc_id                  = aws_vpc.rds.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "ecommerce-dev-rds-${each.key}"
  }
}
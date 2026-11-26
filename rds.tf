resource "aws_db_subnet_group" "rds" {
  name       = "${local.name_prefix}-rds"
  subnet_ids = [for subnet in aws_subnet.rds_private : subnet.id]
}

resource "aws_security_group" "rds" {
  name   = "${local.name_prefix}-rds"
  vpc_id = aws_vpc.rds.id

  ingress {
    description = "PostgreSQL from the project VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.rds.cidr_block]
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${local.name_prefix}-postgres"
  engine            = "postgres"
  engine_version    = "15.19"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "ecommerce"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  storage_encrypted      = true

  deletion_protection       = local.env_config[var.env].deletion_protection
  skip_final_snapshot       = var.env != "prod"
  final_snapshot_identifier = var.env == "prod" ? "ecommerce-prod-postgres-final" : null
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}
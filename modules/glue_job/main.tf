variable "create_job" {
  type    = bool
  default = true
}

variable "source_bucket" {
  type = string
}

variable "target_bucket" {
  type = string
}

variable "script_location" {
  type = string
}

variable "role_arn" {
  type    = string
  default = null
}

resource "aws_iam_role" "glue" {
  count = var.role_arn == null ? 1 : 0
  name  = "ecommerce-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  count      = length(aws_iam_role.glue)
  role       = aws_iam_role.glue[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "data" {
  count = length(aws_iam_role.glue)
  name  = "ecommerce-glue-data"
  role  = aws_iam_role.glue[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = [
          "arn:aws:s3:::${var.source_bucket}",
          "arn:aws:s3:::${var.target_bucket}"
        ]
      },
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = [
          "arn:aws:s3:::${var.source_bucket}/raw/orders/*",
          "arn:aws:s3:::${var.source_bucket}/glue_scripts/orders_etl.py"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.target_bucket}/processed/orders/*"
      }
    ]
  })
}

resource "aws_glue_job" "orders" {
  count             = var.create_job ? 1 : 0
  name              = "orders-etl-job"
  role_arn          = var.role_arn == null ? aws_iam_role.glue[0].arn : var.role_arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = var.script_location
  }

  default_arguments = {
    "--job-language"  = "python"
    "--SOURCE_BUCKET" = var.source_bucket
    "--TARGET_BUCKET" = var.target_bucket
  }

  depends_on = [
    aws_iam_role_policy_attachment.glue_service,
    aws_iam_role_policy.data
  ]
}

output "job_name" {
  value = one(aws_glue_job.orders[*].name)
}
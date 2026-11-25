variable "create_glue_job" {
  type    = bool
  default = true
}

resource "aws_s3_object" "orders_etl" {
  bucket = aws_s3_bucket.data["raw"].id
  key    = "glue_scripts/orders_etl.py"
  source = "${path.module}/glue_scripts/orders_etl.py"
  etag   = filemd5("${path.module}/glue_scripts/orders_etl.py")
}

module "glue_job" {
  create_job = var.create_glue_job
  source     = "./modules/glue_job"

  source_bucket   = aws_s3_bucket.data["raw"].id
  target_bucket   = aws_s3_bucket.data["processed"].id
  script_location = "s3://${aws_s3_object.orders_etl.bucket}/${aws_s3_object.orders_etl.key}"

  depends_on = [aws_s3_object.orders_etl]
}

output "glue_job_name" {
  value = module.glue_job.job_name
}
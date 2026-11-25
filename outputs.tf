output "s3_bucket_names" {
  description = "Nazwy bucketow raw, processed i curated."
  value       = { for layer, bucket in aws_s3_bucket.data : layer => bucket.bucket }
}
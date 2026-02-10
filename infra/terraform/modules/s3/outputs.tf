output "raw_bucket_name" {
  description = "Name of the raw data bucket"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  description = "ARN of the raw data bucket"
  value       = aws_s3_bucket.raw.arn
}

output "staging_bucket_name" {
  description = "Name of the staging bucket"
  value       = aws_s3_bucket.staging.id
}

output "staging_bucket_arn" {
  description = "ARN of the staging bucket"
  value       = aws_s3_bucket.staging.arn
}

output "logs_bucket_name" {
  description = "Name of the logs bucket"
  value       = aws_s3_bucket.logs.id
}

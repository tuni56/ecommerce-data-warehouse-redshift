# S3 Outputs
output "s3_raw_bucket" {
  description = "Name of the raw S3 bucket"
  value       = module.s3.raw_bucket_name
}

output "s3_staging_bucket" {
  description = "Name of the staging S3 bucket"
  value       = module.s3.staging_bucket_name
}

output "s3_logs_bucket" {
  description = "Name of the logs S3 bucket"
  value       = module.s3.logs_bucket_name
}

# Redshift Outputs
output "redshift_endpoint" {
  description = "Redshift Serverless endpoint"
  value       = module.redshift.workgroup_endpoint
}

output "redshift_port" {
  description = "Redshift Serverless port"
  value       = module.redshift.workgroup_port
}

output "redshift_database" {
  description = "Redshift database name"
  value       = module.redshift.database_name
}

# Glue Outputs
output "glue_raw_database" {
  description = "Glue raw database name"
  value       = module.glue.raw_database_name
}

output "glue_staging_database" {
  description = "Glue staging database name"
  value       = module.glue.staging_database_name
}

# IAM Outputs
output "redshift_role_arn" {
  description = "Redshift IAM role ARN"
  value       = module.iam.redshift_role_arn
}

output "glue_role_arn" {
  description = "Glue IAM role ARN"
  value       = module.iam.glue_role_arn
}
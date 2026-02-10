variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "s3_raw_bucket_arn" {
  description = "ARN of the raw S3 bucket"
  type        = string
}

variable "s3_staging_bucket_arn" {
  description = "ARN of the staging S3 bucket"
  type        = string
}

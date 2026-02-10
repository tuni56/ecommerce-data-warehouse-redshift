output "redshift_role_arn" {
  description = "ARN of the Redshift IAM role"
  value       = aws_iam_role.redshift.arn
}

output "glue_role_arn" {
  description = "ARN of the Glue IAM role"
  value       = aws_iam_role.glue.arn
}

output "glue_role_name" {
  description = "Name of the Glue IAM role"
  value       = aws_iam_role.glue.name
}

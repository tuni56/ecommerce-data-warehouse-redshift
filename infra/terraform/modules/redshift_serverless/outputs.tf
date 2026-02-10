output "namespace_id" {
  description = "ID of the Redshift Serverless namespace"
  value       = aws_redshiftserverless_namespace.main.id
}

output "workgroup_id" {
  description = "ID of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.main.id
}

output "workgroup_endpoint" {
  description = "Endpoint of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.main.endpoint[0].address
}

output "workgroup_port" {
  description = "Port of the Redshift Serverless workgroup"
  value       = aws_redshiftserverless_workgroup.main.endpoint[0].port
}

output "database_name" {
  description = "Name of the default database"
  value       = var.database_name
}

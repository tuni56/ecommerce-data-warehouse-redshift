output "raw_database_name" {
  description = "Name of the raw Glue database"
  value       = aws_glue_catalog_database.raw.name
}

output "staging_database_name" {
  description = "Name of the staging Glue database"
  value       = aws_glue_catalog_database.staging.name
}

output "raw_crawler_name" {
  description = "Name of the raw data crawler"
  value       = aws_glue_crawler.raw.name
}

output "staging_crawler_name" {
  description = "Name of the staging data crawler"
  value       = aws_glue_crawler.staging.name
}

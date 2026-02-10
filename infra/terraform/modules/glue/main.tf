# Glue Database
resource "aws_glue_catalog_database" "raw" {
  name = "${var.project_name}_raw_${var.environment}"
  
  description = "Raw data catalog for ${var.project_name}"
}

resource "aws_glue_catalog_database" "staging" {
  name = "${var.project_name}_staging_${var.environment}"
  
  description = "Staging data catalog for ${var.project_name}"
}

# Glue Crawler for Raw Data
resource "aws_glue_crawler" "raw" {
  name          = "${var.project_name}-raw-crawler-${var.environment}"
  role          = var.glue_role_arn
  database_name = aws_glue_catalog_database.raw.name

  s3_target {
    path = "s3://${var.raw_bucket_name}/raw/"
  }

  schedule = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  tags = {
    Name        = "${var.project_name}-raw-crawler-${var.environment}"
    Environment = var.environment
  }
}

# Glue Crawler for Staging Data
resource "aws_glue_crawler" "staging" {
  name          = "${var.project_name}-staging-crawler-${var.environment}"
  role          = var.glue_role_arn
  database_name = aws_glue_catalog_database.staging.name

  s3_target {
    path = "s3://${var.staging_bucket_name}/staging/"
  }

  schedule = "cron(0 3 * * ? *)"  # Daily at 3 AM UTC

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  tags = {
    Name        = "${var.project_name}-staging-crawler-${var.environment}"
    Environment = var.environment
  }
}

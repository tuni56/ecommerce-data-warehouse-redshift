locals {
  project_name = "ecommerce-dwh"
}

# S3 Buckets
module "s3" {
  source = "../../modules/s3"

  project_name = local.project_name
  environment  = var.environment
}

# IAM Roles
module "iam" {
  source = "../../modules/iam"

  project_name           = local.project_name
  environment            = var.environment
  s3_raw_bucket_arn      = module.s3.raw_bucket_arn
  s3_staging_bucket_arn  = module.s3.staging_bucket_arn
}

# Redshift Serverless
module "redshift" {
  source = "../../modules/redshift_serverless"

  project_name   = local.project_name
  environment    = var.environment
  database_name  = var.database_name
  admin_username = var.admin_username
  admin_password = var.admin_password
  base_capacity  = var.base_capacity
  iam_role_arns  = [module.iam.redshift_role_arn]
}

# Glue
module "glue" {
  source = "../../modules/glue"

  project_name         = local.project_name
  environment          = var.environment
  glue_role_arn        = module.iam.glue_role_arn
  raw_bucket_name      = module.s3.raw_bucket_name
  staging_bucket_name  = module.s3.staging_bucket_name
}

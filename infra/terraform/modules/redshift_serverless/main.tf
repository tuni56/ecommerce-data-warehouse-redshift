data "aws_caller_identity" "current" {}

# Redshift Serverless Namespace
resource "aws_redshiftserverless_namespace" "main" {
  namespace_name = "${var.project_name}-${var.environment}"
  
  admin_username = var.admin_username
  admin_user_password = var.admin_password
  
  db_name = var.database_name
  
  iam_roles = var.iam_role_arns

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

# Redshift Serverless Workgroup
resource "aws_redshiftserverless_workgroup" "main" {
  namespace_name = aws_redshiftserverless_namespace.main.namespace_name
  workgroup_name = "${var.project_name}-${var.environment}"
  
  base_capacity = var.base_capacity
  
  publicly_accessible = false

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

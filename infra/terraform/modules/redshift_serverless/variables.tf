variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "dev"
}

variable "admin_username" {
  description = "Admin username for Redshift"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Admin password for Redshift"
  type        = string
  sensitive   = true
}

variable "base_capacity" {
  description = "Base RPU capacity for Redshift Serverless"
  type        = number
  default     = 8
}

variable "iam_role_arns" {
  description = "List of IAM role ARNs to associate with Redshift"
  type        = list(string)
  default     = []
}

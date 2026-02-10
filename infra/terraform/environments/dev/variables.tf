variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "database_name" {
  description = "Redshift database name"
  type        = string
  default     = "dev"
}

variable "admin_username" {
  description = "Redshift admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Redshift admin password"
  type        = string
  sensitive   = true
}

variable "base_capacity" {
  description = "Redshift Serverless base capacity (RPU)"
  type        = number
  default     = 8
}

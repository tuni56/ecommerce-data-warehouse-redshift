# Redshift IAM Role
resource "aws_iam_role" "redshift" {
  name = "${var.project_name}-redshift-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "redshift.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-redshift-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "redshift_s3" {
  name = "redshift-s3-access"
  role = aws_iam_role.redshift.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_raw_bucket_arn,
          "${var.s3_raw_bucket_arn}/*",
          var.s3_staging_bucket_arn,
          "${var.s3_staging_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Glue IAM Role
resource "aws_iam_role" "glue" {
  name = "${var.project_name}-glue-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-glue-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "glue-s3-access"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_raw_bucket_arn,
          "${var.s3_raw_bucket_arn}/*",
          var.s3_staging_bucket_arn,
          "${var.s3_staging_bucket_arn}/*"
        ]
      }
    ]
  })
}

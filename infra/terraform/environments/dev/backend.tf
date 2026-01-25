terraform {
  backend "s3" {
    bucket         = "tf-state-ecommerce-dwh"
    key            = "dev/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tf-locks-ecommerce-dwh"
    encrypt        = true
  }
}

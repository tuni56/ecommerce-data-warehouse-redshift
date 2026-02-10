## Terraform Backend (Dev)

This project uses a remote S3 backend with DynamoDB locking to manage
Terraform state safely and collaboratively.

- Region: us-east-2
- State bucket: tf-state-ecommerce-dwh
- Lock table: tf-locks-ecommerce-dwh
- Environment key prefix: dev/

This setup prevents concurrent state modifications and enables
team-based infrastructure development.

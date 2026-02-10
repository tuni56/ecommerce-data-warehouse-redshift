# Implementation Guide - Ecommerce Data Warehouse on AWS

This guide walks you through deploying the complete data warehouse infrastructure from scratch in `us-east-2`.

## Prerequisites

- AWS Account with admin access
- AWS CLI configured: `aws configure`
- Terraform >= 1.5.0
- Python >= 3.9
- dbt Core >= 1.6.0

## Phase 1: Bootstrap Terraform Backend (5 minutes)

Before deploying infrastructure, create the S3 bucket and DynamoDB table for Terraform state.

### Step 1.1: Create Terraform State Backend

```bash
# Set variables
export AWS_REGION=us-east-2
export TF_STATE_BUCKET=tf-state-ecommerce-dwh
export TF_LOCK_TABLE=tf-locks-ecommerce-dwh

# Create S3 bucket for state
aws s3api create-bucket \
  --bucket $TF_STATE_BUCKET \
  --region $AWS_REGION \
  --create-bucket-configuration LocationConstraint=$AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $TF_STATE_BUCKET \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $TF_STATE_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket $TF_STATE_BUCKET \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name $TF_LOCK_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION
```

### Step 1.2: Verify Backend

```bash
# Check bucket exists
aws s3 ls s3://$TF_STATE_BUCKET

# Check DynamoDB table
aws dynamodb describe-table --table-name $TF_LOCK_TABLE --region $AWS_REGION
```

## Phase 2: Deploy Core Infrastructure (15 minutes)

### Step 2.1: Initialize Terraform

```bash
cd infra/terraform/environments/dev
terraform init
```

### Step 2.2: Review and Apply

```bash
# See what will be created
terraform plan

# Deploy infrastructure
terraform apply
```

This will create:
- S3 buckets (raw, staging, logs)
- Redshift Serverless namespace and workgroup
- IAM roles and policies
- VPC and security groups (if needed)
- Glue database and crawlers

### Step 2.3: Save Outputs

```bash
# Get Redshift endpoint
terraform output redshift_endpoint

# Get S3 bucket names
terraform output s3_raw_bucket
terraform output s3_staging_bucket
```

## Phase 3: Configure dbt (10 minutes)

### Step 3.1: Install dbt

```bash
pip install dbt-redshift
```

### Step 3.2: Configure dbt Profile

```bash
cd analytics/dbt

# Create profiles.yml
cat > ~/.dbt/profiles.yml <<EOF
ecommerce_dwh:
  target: dev
  outputs:
    dev:
      type: redshift
      host: <REDSHIFT_ENDPOINT>
      port: 5439
      user: admin
      password: <YOUR_PASSWORD>
      dbname: dev
      schema: analytics
      threads: 4
      keepalives_idle: 240
      connect_timeout: 10
      ra3_node: true
EOF
```

### Step 3.3: Test Connection

```bash
dbt debug
```

## Phase 4: Load Sample Data (15 minutes)

### Step 4.1: Generate Sample Data

Create a Python script to generate sample ecommerce data:

```bash
cd ../../
mkdir -p scripts
```

### Step 4.2: Upload to S3

```bash
# Upload raw data
aws s3 cp data/raw/orders/ s3://<RAW_BUCKET>/raw/orders/ --recursive
aws s3 cp data/raw/customers/ s3://<RAW_BUCKET>/raw/customers/ --recursive
aws s3 cp data/raw/products/ s3://<RAW_BUCKET>/raw/products/ --recursive
```

### Step 4.3: Run Glue Crawlers

```bash
# Start crawler to catalog raw data
aws glue start-crawler --name ecommerce-raw-crawler --region us-east-2

# Wait for completion
aws glue get-crawler --name ecommerce-raw-crawler --region us-east-2
```

## Phase 5: Run dbt Transformations (10 minutes)

### Step 5.1: Install dbt Dependencies

```bash
cd analytics/dbt
dbt deps
```

### Step 5.2: Run Models

```bash
# Run all models
dbt run

# Run tests
dbt test

# Generate documentation
dbt docs generate
dbt docs serve
```

## Phase 6: Verify Deployment (5 minutes)

### Step 6.1: Query Redshift

```bash
# Using AWS CLI
aws redshift-data execute-statement \
  --workgroup-name ecommerce-dwh-dev \
  --database dev \
  --sql "SELECT COUNT(*) FROM analytics.fact_order_items;" \
  --region us-east-2
```

### Step 6.2: Check Data Quality

```bash
# Run dbt tests
dbt test

# Check row counts
dbt run-operation check_row_counts
```

## Phase 7: Set Up Monitoring (10 minutes)

### Step 7.1: Create CloudWatch Dashboard

```bash
aws cloudwatch put-dashboard \
  --dashboard-name ecommerce-dwh-dev \
  --dashboard-body file://monitoring/cloudwatch-dashboard.json \
  --region us-east-2
```

### Step 7.2: Create Alerts

```bash
# Create SNS topic
aws sns create-topic --name ecommerce-dwh-alerts --region us-east-2

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-2:<ACCOUNT_ID>:ecommerce-dwh-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

## Troubleshooting

### Issue: Terraform Backend Not Found

```bash
# Ensure backend resources exist
aws s3 ls s3://tf-state-ecommerce-dwh
aws dynamodb describe-table --table-name tf-locks-ecommerce-dwh
```

### Issue: Redshift Connection Failed

```bash
# Check security group allows your IP
aws ec2 describe-security-groups --region us-east-2

# Test connectivity
nc -zv <REDSHIFT_ENDPOINT> 5439
```

### Issue: dbt Models Fail

```bash
# Check Redshift logs
aws redshift-data list-statements --region us-east-2

# Run with debug
dbt run --debug
```

## Cost Management

### Daily Costs (Development)
- Redshift Serverless: ~$3-5/day (8 RPU-hours)
- S3: ~$0.10/day (100GB)
- Glue: ~$0.50/day (1 crawler run)
- **Total: ~$4-6/day**

### Stop Resources When Not in Use

```bash
# Pause Redshift (not available for serverless, but you can delete and recreate)
# Delete non-essential resources
terraform destroy -target=module.glue
```

## Next Steps

1. Set up CI/CD pipeline with GitHub Actions
2. Implement incremental dbt models
3. Add data quality monitoring
4. Create business dashboards in QuickSight
5. Implement data retention policies

## Cleanup

To destroy all resources:

```bash
cd infra/terraform/environments/dev
terraform destroy
```

To remove backend (after destroying infrastructure):

```bash
aws s3 rb s3://tf-state-ecommerce-dwh --force
aws dynamodb delete-table --table-name tf-locks-ecommerce-dwh --region us-east-2
```

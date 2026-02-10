# Step-by-Step Implementation Guide

Complete guide to deploy the Ecommerce Data Warehouse from scratch in `us-east-2`.

## Time Estimate: 60 minutes

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform >= 1.5.0 installed
- [ ] Python >= 3.9 installed
- [ ] Git installed

## Quick Start (Automated)

```bash
# Run the automated deployment script
./scripts/deploy.sh
```

## Manual Step-by-Step Guide

### Phase 1: Bootstrap (5 min)

**1.1 Create Terraform Backend**

```bash
cd /home/rocio/Escritorio/ecommerce-data-warehouse-redshift

# Set environment variables
export AWS_REGION=us-east-2
export TF_STATE_BUCKET=tf-state-ecommerce-dwh
export TF_LOCK_TABLE=tf-locks-ecommerce-dwh

# Create S3 bucket
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

# Create DynamoDB table
aws dynamodb create-table \
  --table-name $TF_LOCK_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

# Wait for table
aws dynamodb wait table-exists --table-name $TF_LOCK_TABLE --region $AWS_REGION
```

**1.2 Verify Backend**

```bash
aws s3 ls s3://$TF_STATE_BUCKET
aws dynamodb describe-table --table-name $TF_LOCK_TABLE --region $AWS_REGION --query 'Table.TableStatus'
```

### Phase 2: Deploy Infrastructure (15 min)

**2.1 Configure Terraform**

```bash
cd infra/terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars and set admin_password
nano terraform.tfvars
```

Add this line to `terraform.tfvars`:
```hcl
admin_password = "YourSecurePassword123!"
```

**2.2 Initialize and Deploy**

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (will take ~10 minutes)
terraform apply

# Save outputs
terraform output > ../../outputs.txt
```

**2.3 Verify Resources**

```bash
# Check S3 buckets
aws s3 ls | grep ecommerce-dwh

# Check Redshift
aws redshift-serverless list-workgroups --region us-east-2

# Check Glue
aws glue get-databases --region us-east-2
```

### Phase 3: Generate and Upload Data (10 min)

**3.1 Generate Sample Data**

```bash
cd /home/rocio/Escritorio/ecommerce-data-warehouse-redshift

# Generate data
python3 scripts/generate_sample_data.py
```

**3.2 Upload to S3**

```bash
# Get bucket name from Terraform output
export RAW_BUCKET=$(terraform -chdir=infra/terraform/environments/dev output -raw s3_raw_bucket)

# Upload data
aws s3 sync data/raw/ s3://${RAW_BUCKET}/raw/ --region us-east-2

# Verify upload
aws s3 ls s3://${RAW_BUCKET}/raw/ --recursive
```

**3.3 Run Glue Crawler**

```bash
# Start crawler
aws glue start-crawler --name ecommerce-dwh-raw-crawler-dev --region us-east-2

# Check status (wait until READY)
aws glue get-crawler --name ecommerce-dwh-raw-crawler-dev --region us-east-2 --query 'Crawler.State'

# View cataloged tables
aws glue get-tables --database-name ecommerce_dwh_raw_dev --region us-east-2
```

### Phase 4: Configure dbt (10 min)

**4.1 Install dbt**

```bash
pip install dbt-redshift
```

**4.2 Configure Profile**

```bash
# Get Redshift endpoint
export REDSHIFT_ENDPOINT=$(terraform -chdir=infra/terraform/environments/dev output -raw redshift_endpoint)

# Create dbt profile
mkdir -p ~/.dbt
cat > ~/.dbt/profiles.yml <<EOF
ecommerce_dwh:
  target: dev
  outputs:
    dev:
      type: redshift
      host: ${REDSHIFT_ENDPOINT}
      port: 5439
      user: admin
      password: YourSecurePassword123!
      dbname: dev
      schema: analytics
      threads: 4
      keepalives_idle: 240
      connect_timeout: 10
      ra3_node: true
EOF
```

**4.3 Test Connection**

```bash
cd analytics/dbt
dbt debug
```

### Phase 5: Load Data to Redshift (15 min)

**5.1 Create Staging Tables**

Connect to Redshift and create staging tables:

```bash
# Using AWS Redshift Data API
aws redshift-data execute-statement \
  --workgroup-name ecommerce-dwh-dev \
  --database dev \
  --sql "CREATE SCHEMA IF NOT EXISTS staging;" \
  --region us-east-2
```

**5.2 Copy Data from S3**

```sql
-- Get IAM role ARN
export REDSHIFT_ROLE=$(terraform -chdir=infra/terraform/environments/dev output -raw redshift_role_arn)

-- Copy customers
COPY staging.customers
FROM 's3://${RAW_BUCKET}/raw/customers/'
IAM_ROLE '${REDSHIFT_ROLE}'
CSV
IGNOREHEADER 1;

-- Copy products
COPY staging.products
FROM 's3://${RAW_BUCKET}/raw/products/'
IAM_ROLE '${REDSHIFT_ROLE}'
CSV
IGNOREHEADER 1;

-- Copy orders
COPY staging.orders
FROM 's3://${RAW_BUCKET}/raw/orders/'
IAM_ROLE '${REDSHIFT_ROLE}'
CSV
IGNOREHEADER 1;

-- Copy order_items
COPY staging.order_items
FROM 's3://${RAW_BUCKET}/raw/order_items/'
IAM_ROLE '${REDSHIFT_ROLE}'
CSV
IGNOREHEADER 1;
```

### Phase 6: Run dbt Transformations (10 min)

**6.1 Run Models**

```bash
cd analytics/dbt

# Install dependencies
dbt deps

# Run all models
dbt run

# Run tests
dbt test

# Generate docs
dbt docs generate
dbt docs serve
```

### Phase 7: Verify and Query (5 min)

**7.1 Query Data**

```bash
# Count records
aws redshift-data execute-statement \
  --workgroup-name ecommerce-dwh-dev \
  --database dev \
  --sql "SELECT 'customers' as table_name, COUNT(*) as row_count FROM analytics.dim_customers
         UNION ALL
         SELECT 'products', COUNT(*) FROM analytics.dim_products
         UNION ALL
         SELECT 'orders', COUNT(*) FROM analytics.fact_order_items;" \
  --region us-east-2
```

**7.2 Sample Analytics Query**

```sql
-- Monthly revenue
SELECT 
    DATE_TRUNC('month', order_date) as month,
    SUM(total_amount) as revenue,
    COUNT(DISTINCT order_id) as num_orders
FROM analytics.fact_order_items
GROUP BY 1
ORDER BY 1 DESC;
```

## Troubleshooting

### Issue: Terraform Backend Error

```bash
# Verify backend exists
aws s3 ls s3://tf-state-ecommerce-dwh
aws dynamodb describe-table --table-name tf-locks-ecommerce-dwh --region us-east-2
```

### Issue: Redshift Connection Timeout

```bash
# Check workgroup is active
aws redshift-serverless get-workgroup --workgroup-name ecommerce-dwh-dev --region us-east-2

# Redshift Serverless is private by default - you may need to:
# 1. Use AWS Redshift Query Editor v2 in console
# 2. Or set publicly_accessible = true in Terraform (not recommended for prod)
```

### Issue: Glue Crawler Fails

```bash
# Check crawler logs
aws glue get-crawler --name ecommerce-dwh-raw-crawler-dev --region us-east-2

# Verify S3 data exists
aws s3 ls s3://${RAW_BUCKET}/raw/ --recursive
```

### Issue: dbt Connection Failed

```bash
# Test with psql
psql -h ${REDSHIFT_ENDPOINT} -U admin -d dev -p 5439

# Or use AWS Query Editor v2 in console
```

## Cost Monitoring

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-28 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

## Cleanup

```bash
# Destroy infrastructure
cd infra/terraform/environments/dev
terraform destroy

# Remove backend (optional)
aws s3 rb s3://tf-state-ecommerce-dwh --force
aws dynamodb delete-table --table-name tf-locks-ecommerce-dwh --region us-east-2
```

## Next Steps

1. ✅ Infrastructure deployed
2. ✅ Sample data loaded
3. ✅ dbt transformations running
4. [ ] Set up CI/CD with GitHub Actions
5. [ ] Create QuickSight dashboards
6. [ ] Implement incremental models
7. [ ] Add data quality monitoring
8. [ ] Set up CloudWatch alarms

## Support

- Check logs: `terraform show`
- AWS Console: https://console.aws.amazon.com/
- dbt docs: https://docs.getdbt.com/

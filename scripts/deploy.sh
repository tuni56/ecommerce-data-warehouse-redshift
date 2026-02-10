#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Ecommerce Data Warehouse - Quick Start${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform not found. Please install it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Set variables
export AWS_REGION=us-east-2
export TF_STATE_BUCKET=tf-state-ecommerce-dwh
export TF_LOCK_TABLE=tf-locks-ecommerce-dwh
export PROJECT_NAME=ecommerce-dwh
export ENVIRONMENT=dev

echo -e "${YELLOW}Step 1: Creating Terraform backend resources...${NC}"

# Check if bucket exists
if aws s3 ls "s3://${TF_STATE_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket for Terraform state..."
    aws s3api create-bucket \
        --bucket ${TF_STATE_BUCKET} \
        --region ${AWS_REGION} \
        --create-bucket-configuration LocationConstraint=${AWS_REGION}
    
    aws s3api put-bucket-versioning \
        --bucket ${TF_STATE_BUCKET} \
        --versioning-configuration Status=Enabled
    
    aws s3api put-bucket-encryption \
        --bucket ${TF_STATE_BUCKET} \
        --server-side-encryption-configuration '{
          "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
              "SSEAlgorithm": "AES256"
            }
          }]
        }'
    
    aws s3api put-public-access-block \
        --bucket ${TF_STATE_BUCKET} \
        --public-access-block-configuration \
          BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    echo -e "${GREEN}✓ S3 bucket created${NC}"
else
    echo -e "${GREEN}✓ S3 bucket already exists${NC}"
fi

# Check if DynamoDB table exists
if ! aws dynamodb describe-table --table-name ${TF_LOCK_TABLE} --region ${AWS_REGION} &> /dev/null; then
    echo "Creating DynamoDB table for state locking..."
    aws dynamodb create-table \
        --table-name ${TF_LOCK_TABLE} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region ${AWS_REGION}
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name ${TF_LOCK_TABLE} --region ${AWS_REGION}
    echo -e "${GREEN}✓ DynamoDB table created${NC}"
else
    echo -e "${GREEN}✓ DynamoDB table already exists${NC}"
fi

echo ""
echo -e "${YELLOW}Step 2: Initializing Terraform...${NC}"
cd infra/terraform/environments/dev

# Create terraform.tfvars if it doesn't exist
if [ ! -f terraform.tfvars ]; then
    echo "Creating terraform.tfvars..."
    cp terraform.tfvars.example terraform.tfvars
    
    # Prompt for password
    echo ""
    read -sp "Enter Redshift admin password (min 8 chars, must include uppercase, lowercase, and number): " ADMIN_PASSWORD
    echo ""
    
    echo "admin_password = \"${ADMIN_PASSWORD}\"" >> terraform.tfvars
    echo -e "${GREEN}✓ terraform.tfvars created${NC}"
fi

terraform init

echo ""
echo -e "${YELLOW}Step 3: Planning infrastructure...${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}Step 4: Applying infrastructure...${NC}"
read -p "Do you want to apply these changes? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
    terraform apply tfplan
    echo -e "${GREEN}✓ Infrastructure deployed successfully!${NC}"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Configure dbt with the Redshift endpoint"
    echo "2. Upload sample data to S3"
    echo "3. Run Glue crawlers"
    echo "4. Execute dbt transformations"
    echo ""
    echo "Get outputs:"
    echo "  terraform output"
    echo ""
else
    echo -e "${YELLOW}Deployment cancelled${NC}"
    rm tfplan
fi

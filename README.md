# Ecommerce Data Warehouse on Amazon Redshift Serverless

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?logo=terraform)](infra/terraform)
[![dbt](https://img.shields.io/badge/Transform-dbt-FF694B?logo=dbt)](analytics/dbt)

A production-grade data warehouse implementation for ecommerce analytics, built on AWS using modern data engineering practices. This project demonstrates end-to-end data pipeline design, from raw ingestion to analytics-ready dimensional models.

## Business Value

**For C-Level:**
- Single source of truth for ecommerce metrics (revenue, customer lifetime value, product performance)
- Serverless architecture reduces operational overhead and scales automatically with demand
- Cost-optimized design with pay-per-query pricing model
- Historical tracking enables trend analysis and forecasting

**For Technical Teams:**
- Medallion architecture (Bronze → Silver → Gold) ensures data quality and lineage
- Infrastructure as Code enables reproducible deployments across environments
- Incremental processing minimizes compute costs and latency
- Star schema design optimized for BI tool performance

## Architecture

The solution implements a modern lakehouse pattern with three distinct layers:

```
Source Systems → S3 (Raw/Bronze) → Glue ETL → S3 (Staging/Silver) → Redshift (Gold) → BI Tools
```

**Key Components:**
- **Amazon S3**: Immutable raw data storage and staging layer
- **AWS Glue**: Serverless ETL for data cleaning and standardization
- **Amazon Redshift Serverless**: Analytics engine with star schema dimensional model
- **dbt**: SQL-based transformations with built-in testing and documentation
- **Terraform**: Infrastructure provisioning with modular, reusable components

[Detailed architecture documentation →](docs/architecture.md)

## Data Model

Star schema optimized for analytical queries:

**Fact Table:**
- `fact_order_items` - Grain: one row per order item

**Dimensions:**
- `dim_customers` - SCD Type 2 for historical tracking
- `dim_products` - SCD Type 2 for price/attribute changes
- `dim_date` - Standard date dimension for time-series analysis
- `dim_payment_methods`
- `dim_shipment_status`

This design prevents double-counting, enables flexible slicing/dicing, and maintains historical accuracy for point-in-time reporting.

[Data model details →](docs/data_model.md)

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Storage | Amazon S3 | Raw and staging data lake |
| ETL | AWS Glue | Serverless data processing |
| Warehouse | Redshift Serverless | Analytics engine |
| Transformation | dbt Core | SQL-based modeling & testing |
| IaC | Terraform | Infrastructure provisioning |
| Orchestration | AWS Step Functions | Workflow coordination |
| Monitoring | CloudWatch | Logging and alerting |

## Project Structure

```
.
├── analytics/
│   ├── dbt/              # dbt models, tests, and documentation
│   └── sql_examples/     # Sample analytical queries
├── infra/
│   ├── terraform/        # Infrastructure as Code
│   │   ├── modules/      # Reusable Terraform modules
│   │   └── environments/ # Environment-specific configs (dev/prod)
│   └── diagrams/         # Architecture diagrams
└── docs/                 # Technical documentation
```

## Quick Start

### Prerequisites

- AWS Account with appropriate IAM permissions
- Terraform >= 1.5.0
- AWS CLI configured with credentials
- dbt Core >= 1.6.0
- Python >= 3.9

### Deployment

**1. Clone the repository**
```bash
git clone https://github.com/<your-username>/ecommerce-data-warehouse-redshift.git
cd ecommerce-data-warehouse-redshift
```

**2. Initialize Terraform**
```bash
cd infra/terraform/environments/dev
terraform init
```

**3. Review and apply infrastructure**
```bash
terraform plan
terraform apply
```

This provisions:
- S3 buckets (raw, staging, logs)
- Redshift Serverless namespace and workgroup
- Glue jobs and crawlers
- IAM roles and policies
- VPC and security groups

**4. Configure dbt**
```bash
cd analytics/dbt
cp profiles.yml.example profiles.yml
# Edit profiles.yml with your Redshift endpoint
```

**5. Run dbt transformations**
```bash
dbt deps
dbt run --target dev
dbt test
```

**6. Verify deployment**
```bash
# Query Redshift to confirm data loaded
aws redshift-data execute-statement \
  --workgroup-name ecommerce-dwh-dev \
  --database dev \
  --sql "SELECT COUNT(*) FROM fact_order_items;"
```

## Key Features

### Infrastructure as Code
- Modular Terraform design for reusability across environments
- Separate state management per environment (dev/staging/prod)
- Automated resource tagging for cost allocation

### Data Quality
- dbt tests for uniqueness, referential integrity, and not-null constraints
- Row count reconciliation between layers
- Freshness checks for SLA monitoring

### Performance Optimization
- Distribution keys on fact tables for co-located joins
- Sort keys on date columns for time-series queries
- Incremental models to minimize full table scans
- Workload management (WLM) configuration for query prioritization

### Cost Management
- Redshift Serverless auto-scales based on workload
- S3 lifecycle policies for archival to Glacier
- Glue job bookmarks prevent reprocessing
- Development environment with reduced capacity

## Sample Analytics Queries

**Monthly Revenue Trend:**
```sql
SELECT 
    d.year_month,
    SUM(f.total_amount) as revenue
FROM fact_order_items f
JOIN dim_date d ON f.order_date_key = d.date_key
GROUP BY 1
ORDER BY 1;
```

**Top Products by Revenue:**
```sql
SELECT 
    p.product_name,
    SUM(f.quantity) as units_sold,
    SUM(f.total_amount) as revenue
FROM fact_order_items f
JOIN dim_products p ON f.product_key = p.product_key
WHERE p.is_current = TRUE
GROUP BY 1
ORDER BY 3 DESC
LIMIT 10;
```

[More examples →](analytics/sql_examples/)

## Design Decisions

Key architectural choices and tradeoffs:

- **Redshift Serverless vs Provisioned**: Chose serverless for automatic scaling and simplified operations. Suitable for variable workloads with unpredictable query patterns.
- **Star Schema vs Data Vault**: Star schema prioritizes query simplicity and BI tool compatibility over extreme flexibility.
- **SCD Type 2 for dimensions**: Enables point-in-time analysis at the cost of increased storage and join complexity.
- **Glue vs EMR**: Glue's serverless model reduces operational burden for moderate data volumes (<10TB).
- **S3 as staging layer**: Decouples ingestion from transformation, enables reprocessing, and reduces Redshift storage costs.

[Full decision log →](docs/decisions.md)

## Monitoring & Observability

- **CloudWatch Dashboards**: Query performance, RPU consumption, data freshness
- **Glue Job Metrics**: Success rate, duration, DPU utilization
- **dbt Test Results**: Data quality KPIs tracked over time
- **Cost Alerts**: Budget thresholds for Redshift and Glue

## Development Workflow

This project follows GitFlow branching strategy:

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/*` - Individual feature branches
- `hotfix/*` - Emergency production fixes

**Contributing:**
1. Create feature branch from `develop`
2. Implement changes with tests
3. Submit PR with description of changes
4. Merge to `develop` after review
5. Release to `main` when ready for production

## Roadmap

- [ ] CI/CD pipeline with GitHub Actions
- [ ] Incremental dbt models for large fact tables
- [ ] Real-time ingestion with Kinesis Data Firehose
- [ ] ML integration for customer churn prediction
- [ ] Cross-region disaster recovery

## Cost Estimation

**Development Environment** (monthly):
- Redshift Serverless: ~$50-100 (8 RPU-hours/day)
- S3 Storage: ~$5 (100GB)
- Glue Jobs: ~$20 (daily runs)
- **Total: ~$75-125/month**

**Production Environment** (monthly, estimated):
- Redshift Serverless: ~$500-1000 (depends on query load)
- S3 Storage: ~$50 (1TB)
- Glue Jobs: ~$100 (hourly incremental loads)
- **Total: ~$650-1150/month**

Use [AWS Pricing Calculator](https://calculator.aws) for detailed estimates based on your workload.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

**Rocio** - AWS Data Engineer  
[GitHub](https://github.com/<your-username>) | [LinkedIn](https://linkedin.com/in/<your-profile>)

---

*This project is a portfolio demonstration and not affiliated with any commercial entity.*

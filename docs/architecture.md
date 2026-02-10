# Data Flow – Ecommerce Data Warehouse (Redshift)

## Overview
This project implements a modern data warehouse on AWS using a medallion architecture (bronze, silver, gold) and Amazon Redshift Serverless as the analytical engine.
The architecture prioritizes:
- Reliability
- Incremental processing
- Clear data ownership
- Cost-aware design
- Analytics-friendly modeling

## Step 1 – Source Systems
Ecommerce transactional systems, simulated as:
- Orders
- Order items
- Customers
- Products
- Payments
- Shipments
These sources represent typical OLTP workloads and generate append-heavy data with late-arriving updates.

## Step 2 – Raw ingestion (Bronze)
**Amazon S3 – Raw zone**

**Purpose:**
- Immutable landing zone
- Preserve source fidelity
- Enable reprocessing and backfills

**Characteristics:**
- Append-only
- Minimal or no transformation
- Partitioned by ingestion date

**Example structure:**
s3://ecommerce-dwh-<env>/raw/
  ├── orders/
  ├── order_items/
  ├── customers/


## Step 3 – Data cleaning & standardization (Silver)
**AWS Glue ETL → Amazon S3 (Staging zone)**

**Purpose:**
- Apply data quality rules
- Normalize schemas
- Handle late-arriving data
- Prepare analytics-safe datasets

**Typical transformations:**
- Type casting
- Deduplication
- Null handling
- Standardized timestamps
- Business key normalization

**Example structure:**
s3://ecommerce-dwh-<env>/staging/
├── orders_cleaned/
├── customers_cleaned/


## Step 4 – Analytics-ready data (Gold)
**Amazon Redshift Serverless**

**Purpose:**
- Serve BI and analytics workloads
- Enforce star schema modeling
- Enable performant queries

**Characteristics:**
- Fact tables at well-defined grain
- Conformed dimensions
- Incremental loads (MERGE / upsert)
- Late-arriving facts handled explicitly

**Example:**
- fact_orders
- dim_customers
- dim_products
- dim_date
Redshift represents the Gold layer of the medallion architecture.

## Step 5 – Consumption
Consumers include:
- BI tools
- Analytics queries
- Ad-hoc exploration
- Downstream data products
Redshift is the single source of truth for analytics.

## Observability & Reliability (cross-cutting)
- Glue job logging
- Data quality checks (row counts, nulls, freshness)
- Deterministic, idempotent transformations
- Ability to reprocess from Raw at any time


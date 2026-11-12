# Architecture — Ecommerce Data Warehouse on AWS

## 1. Overview

This project implements an ecommerce data warehouse architecture on AWS, designed to centralize source data, transform it into an analytical model, and make it available for reporting and business intelligence.

The architecture is based on the following services and tools:

- **Amazon S3:** data lake storage for raw and intermediate datasets.
- **AWS Glue:** data cataloging and data integration.
- **Amazon Redshift Serverless:** analytical data warehouse.
- **dbt Core:** SQL transformations, data testing, and documentation.
- **Terraform:** infrastructure provisioning.
- **AWS Step Functions:** workflow orchestration.
- **Amazon CloudWatch:** operational monitoring.

The architecture separates data ingestion, storage, transformation, and analytical consumption.

## 2. Architecture Goals

The solution is designed to:

- Establish a centralized analytical repository for ecommerce data.
- Preserve source data in Amazon S3.
- Separate raw and intermediate data layers.
- Use managed AWS services for data integration and warehousing.
- Apply a dimensional data model optimized for analytical queries.
- Maintain historical changes in customer and product attributes.
- Manage infrastructure through Terraform.
- Organize SQL transformations and data quality tests using dbt Core.
- Support workflow orchestration and operational monitoring.

## 3. Architecture Components

### 3.1 Amazon S3 — Data Lake Storage

Amazon S3 provides the storage layer for incoming and intermediate ecommerce datasets.

The architecture separates data into two logical zones:

| Zone | Purpose |
|---|---|
| Raw | Stores source datasets in their original structure. |
| Staging | Stores intermediate datasets prepared for warehouse loading. |

This separation preserves the original source data while providing a dedicated location for data preparation and integration.

### 3.2 AWS Glue — Data Catalog and Integration

AWS Glue provides data cataloging and integration capabilities.

Its responsibilities include:

- Cataloging datasets stored in Amazon S3.
- Maintaining metadata about source data.
- Supporting data preparation and integration workflows.
- Making datasets discoverable for downstream processing.

### 3.3 Amazon Redshift Serverless — Data Warehouse

Amazon Redshift Serverless provides the analytical storage and query layer.

The warehouse follows a dimensional modeling approach, using a star schema composed of:

- `fact_order_items`
- `dim_customers`
- `dim_products`
- `dim_date`
- `dim_payment_methods`
- `dim_shipment_status`

The fact table uses one row per order item as its grain.

Customer and product dimensions implement Slowly Changing Dimension Type 2 (SCD Type 2) to preserve historical attribute changes.

### 3.4 dbt Core — Data Transformation

dbt Core manages SQL transformations within Amazon Redshift.

The transformation layer is organized into three logical stages:

| Layer | Responsibility |
|---|---|
| Staging | Standardizes source data and prepares it for downstream transformations. |
| Intermediate | Applies business logic and combines related datasets. |
| Marts | Publishes analytical fact and dimension tables. |

dbt also provides data testing and documentation capabilities.

### 3.5 Terraform — Infrastructure as Code

Terraform manages the provisioning of the AWS infrastructure.

Infrastructure definitions are maintained in the repository, allowing the environment to be deployed and managed through version-controlled configuration.

### 3.6 AWS Step Functions — Workflow Orchestration

AWS Step Functions coordinates the data workflow and its dependent execution steps.

It provides a managed mechanism for defining workflow sequencing and execution behavior.

### 3.7 Amazon CloudWatch — Monitoring

Amazon CloudWatch provides operational visibility into the AWS environment and data workflows.

It supports monitoring through metrics, logs, dashboards, and alarms.

## 4. End-to-End Data Flow

The architecture follows this logical sequence:

1. Ecommerce source datasets are delivered to Amazon S3.
2. Raw datasets are cataloged and processed through AWS Glue.
3. Intermediate datasets are stored in the S3 staging layer.
4. Prepared data is loaded into Amazon Redshift Serverless.
5. dbt Core executes SQL transformations within the warehouse.
6. The transformation layer produces the dimensional star schema.
7. Data quality tests validate the resulting models.
8. AWS Step Functions coordinates workflow execution.
9. Amazon CloudWatch provides operational monitoring.

## 5. Repository Organization

The project separates infrastructure, analytics, and documentation:

```text
.
├── README.md
├── docs/
│   ├── architecture.md
│   ├── architecture-diagram.md
│   ├── data_model.md
│   ├── decisions.md
│   └── implementation-guide.md
├── infra/
│   └── terraform/
│       └── environments/
│           └── dev/
└── analytics/
    └── dbt/
```

### Infrastructure

`infra/terraform/` contains the Terraform configuration responsible for AWS resource provisioning.

### Analytics

`analytics/dbt/` contains the dbt project responsible for warehouse transformations, tests, and documentation.

### Documentation

`docs/` contains the architecture definition, architecture diagram, data model, architectural decisions, and implementation instructions.

## 6. Architectural Principles

The solution follows these principles:

- **Separation of concerns:** ingestion, storage, transformation, and analytics have distinct responsibilities.
- **Managed services:** AWS managed services reduce the operational burden of infrastructure management.
- **Infrastructure as Code:** Terraform provides repeatable infrastructure definitions.
- **Modular transformations:** dbt organizes SQL logic into reusable and understandable model layers.
- **Dimensional modeling:** the star schema supports analytical queries and reporting.
- **Historical data preservation:** SCD Type 2 maintains customer and product history.

## 7. Related Documentation

- [Architecture Diagram](architecture-diagram.md)
- [Data Model](data_model.md)
- [Architectural Decisions](decisions.md)
- [Implementation Guide](implementation-guide.md)

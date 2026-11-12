# Implementation Guide

## 1. Purpose

This guide describes how to implement the Ecommerce Data Warehouse defined in the project README and supporting architecture documentation.

The implementation follows this sequence:

1. Provision AWS infrastructure with Terraform.
2. Establish Amazon S3 raw and staging zones.
3. Configure AWS Glue for cataloging and data integration.
4. Deploy the Amazon Redshift Serverless warehouse.
5. Configure dbt Core and implement the dimensional models.
6. Implement Slowly Changing Dimensions (SCD Type 2) for customers and products.
7. Orchestrate the pipeline with AWS Step Functions.
8. Configure monitoring with Amazon CloudWatch.
9. Validate the complete data pipeline.

The implementation is organized around a development environment. Resource names, account-specific values, credentials, and deployment parameters must be supplied through environment configuration rather than hardcoded in the project.

## 2. Prerequisites

Before provisioning the environment, prepare the following:

### AWS

- An AWS account with permissions to create and manage the required services.
- AWS CLI installed and configured.
- An IAM identity with permissions for Terraform deployment and application execution.
- Access to the target AWS Region.
- A defined network and security configuration for Redshift Serverless.

### Local development tools

- Terraform.
- Python.
- dbt Core with the Amazon Redshift adapter.
- Git.
- AWS CLI.

Verify the main tools are available:

```bash
aws --version
terraform version
python --version
git --version
dbt --version
```

The dbt command should be executed after installing the appropriate adapter.

## 3. Repository organization

Keep infrastructure, analytics, and documentation separated.

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

Responsibilities:

| Directory | Responsibility |
|---|---|
| `docs/` | Architecture, data model, design decisions, and implementation documentation |
| `infra/terraform/` | AWS infrastructure provisioning |
| `infra/terraform/environments/dev/` | Development environment configuration |
| `analytics/dbt/` | Data transformations, tests, and documentation |

Keep environment-specific configuration outside reusable infrastructure definitions wherever possible.

## 4. Provision AWS infrastructure with Terraform

Terraform is responsible for defining and provisioning the AWS infrastructure.

The development environment should include the resources required by the architecture:

- Amazon S3 storage.
- AWS Glue cataloging and integration resources.
- Amazon Redshift Serverless.
- IAM roles and policies.
- AWS Step Functions resources.
- Amazon CloudWatch monitoring resources.
- Supporting networking and security configuration.

### 4.1 Configure the Terraform environment

Navigate to the development environment:

```bash
cd infra/terraform/environments/dev
```

Configure the Terraform backend and provider for the target AWS environment.

The backend should support persistent state storage and state locking. Do not commit state files, credentials, or sensitive configuration to Git.

### 4.2 Initialize and validate

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the execution plan before applying changes.

When the plan is correct:

```bash
terraform apply
```

Capture relevant outputs, such as resource identifiers and endpoints, for use by subsequent configuration steps.

## 5. Configure Amazon S3 storage

Amazon S3 provides the storage foundation for the data pipeline.

The architecture separates incoming data from data prepared for downstream processing.

### 5.1 Raw zone

The raw zone stores source data in its original form.

Its responsibilities are:

- Preserve source data.
- Maintain an ingestion history.
- Support traceability and reprocessing.
- Separate incoming data from transformed datasets.

A logical prefix organization can be used to separate datasets and ingestion periods:

```text
s3://<bucket-name>/raw/<source>/<dataset>/
```

### 5.2 Staging zone

The staging zone contains data prepared for downstream integration and warehouse loading.

Its responsibilities are:

- Store processed datasets.
- Provide a structured handoff between ingestion and warehouse loading.
- Support repeatable processing.
- Maintain separation from the original source data.

A logical prefix organization:

```text
s3://<bucket-name>/staging/<dataset>/
```

The bucket names, retention policies, encryption configuration, and lifecycle rules should be defined through Terraform.

## 6. Configure AWS Glue

AWS Glue provides data cataloging and integration capabilities.

### 6.1 Data Catalog

Create the catalog structures required to describe the datasets stored in S3.

The catalog should expose the relevant raw and staging datasets, including their schemas and storage locations.

### 6.2 Data integration

Configure the Glue resources needed to process incoming datasets and prepare them for downstream consumption.

The integration process should preserve the distinction between raw source data and processed staging data.

Schema changes should be considered explicitly. Changes to source structures must not silently invalidate downstream transformations.

## 7. Deploy Amazon Redshift Serverless

Amazon Redshift Serverless is the analytical warehouse.

Configure the warehouse with the required database, namespace, workgroup, security settings, and access permissions.

The warehouse must be accessible to the dbt execution environment while remaining protected by the configured network and IAM controls.

### 7.1 Warehouse organization

Organize the analytical models into logical schemas that distinguish:

- Staging models.
- Intermediate transformations.
- Business-facing dimensional models.

The dimensional model is defined in `docs/data_model.md`.

The central fact table is:

`fact_order_items`

Its grain is one row per order item.

The dimensions are:

- `dim_customers`
- `dim_products`
- `dim_date`
- `dim_payment_methods`
- `dim_shipment_status`

## 8. Configure dbt Core

dbt Core manages the warehouse transformation layer.

The dbt project should be located in:

```text
analytics/dbt/
```

### 8.1 Install the Redshift adapter

Create and activate a Python virtual environment, then install the required adapter:

```bash
python -m venv .venv
source .venv/bin/activate
pip install dbt-core dbt-redshift
```

Verify the installation:

```bash
dbt --version
```

### 8.2 Configure the connection

Configure the dbt profile to connect to the Redshift Serverless warehouse.

Connection parameters must be supplied securely. Do not store passwords, access keys, or other secrets in the repository.

The profile should identify:

- The Redshift Serverless host.
- The database.
- The target schema.
- The user or supported authentication method.
- The development target.

Validate the connection:

```bash
dbt debug
```

### 8.3 Organize the transformation layers

Use three logical model layers.

**Staging**

Prepare source data for analytical transformations.

Typical responsibilities:

- Standardize column names.
- Apply consistent data types.
- Handle source-level nulls.
- Normalize source representations.
- Establish consistent interfaces for downstream models.

**Intermediate**

Implement reusable business transformations.

Typical responsibilities:

- Combine related datasets.
- Apply business rules.
- Prepare records for dimensional modeling.
- Resolve transformation logic shared by multiple models.

**Marts**

Expose the dimensional model for analytical consumption.

The marts layer contains:

- `fact_order_items`
- `dim_customers`
- `dim_products`
- `dim_date`
- `dim_payment_methods`
- `dim_shipment_status`

### 8.4 Validate dbt models

Run the project checks:

```bash
dbt parse
dbt compile
dbt test
```

Execute the transformations:

```bash
dbt run
```

Run the tests again after execution:

```bash
dbt test
```

Generate project documentation:

```bash
dbt docs generate
```

The generated documentation should describe model dependencies, columns, and tests.

## 9. Implement SCD Type 2

The customer and product dimensions use Slowly Changing Dimension Type 2.

The purpose is to preserve historical versions of records when tracked attributes change.

### 9.1 Historical record management

When a tracked attribute changes:

1. Identify the currently active dimension record.
2. Close the previous version by setting its expiration timestamp.
3. Mark the previous version as inactive.
4. Insert a new version with the updated attributes.
5. Mark the new version as active.

The implementation should maintain effective dates and a current-record indicator.

A conceptual structure includes:

| Column | Purpose |
|---|---|
| Business key | Identifies the source customer or product |
| Effective start timestamp | Indicates when the version became valid |
| Effective end timestamp | Indicates when the version stopped being valid |
| Current flag | Identifies the active version |

Use the same historical tracking approach for both `dim_customers` and `dim_products`.

### 9.2 Historical integrity

Validate that:

- Each business key has no more than one current record.
- Historical records have valid effective date ranges.
- Attribute changes create new versions rather than overwriting tracked history.
- Fact records can be associated with the appropriate dimension version.

The precise surrogate-key strategy and tracked attributes should be documented as part of the dimensional model implementation.

## 10. Orchestrate the pipeline with AWS Step Functions

AWS Step Functions coordinates the pipeline execution.

The workflow should represent the logical sequence of processing stages:

1. Start the pipeline execution.
2. Process and catalog incoming data.
3. Prepare datasets in the S3 staging zone.
4. Load or make the prepared data available in Redshift.
5. Execute dbt transformations.
6. Run data quality checks.
7. Complete the execution or handle failures.

The workflow should define explicit success and failure paths.

### 10.1 Failure handling

Implement failure handling for individual processing stages.

The workflow should:

- Capture execution errors.
- Avoid treating failed transformations as successful pipeline runs.
- Support retries where appropriate.
- Preserve enough execution information for troubleshooting.
- Make failed stages identifiable.

Step Functions should coordinate the process rather than contain the transformation logic itself.

## 11. Configure Amazon CloudWatch monitoring

CloudWatch provides operational visibility into the pipeline.

Monitoring should cover the main components:

- AWS Glue execution.
- Step Functions workflow executions.
- Redshift Serverless activity.
- Pipeline failures.
- Processing duration.

### 11.1 Logs and metrics

Configure log collection and relevant metrics for the pipeline components.

Monitor:

- Failed executions.
- Processing errors.
- Unsuccessful data quality checks.
- Unusual changes in execution duration.
- Repeated retries or failed stages.

### 11.2 Operational visibility

Use CloudWatch dashboards and alarms to make pipeline health visible.

Operational monitoring should help answer:

- Did the pipeline complete?
- Which stage failed?
- When did the failure occur?
- Is the problem recurring?
- Does the pipeline require intervention?

## 12. End-to-end validation

Validate the system progressively rather than waiting until every component has been deployed.

### Infrastructure

- [ ] Terraform initializes successfully.
- [ ] Terraform configuration passes validation.
- [ ] Required AWS resources are provisioned.
- [ ] IAM permissions follow least-privilege principles.
- [ ] Network access to Redshift is correctly configured.

### Storage and integration

- [ ] Raw data can be stored in S3.
- [ ] Staging data can be written to S3.
- [ ] Glue can catalog the required datasets.
- [ ] Data integration processes complete successfully.

### Warehouse and transformations

- [ ] Redshift Serverless is accessible.
- [ ] dbt connects successfully.
- [ ] Staging models execute.
- [ ] Intermediate models execute.
- [ ] Dimensional models are created.
- [ ] `fact_order_items` respects its declared grain.
- [ ] Customer and product history is preserved through SCD Type 2.
- [ ] dbt tests pass.

### Orchestration and monitoring

- [ ] Step Functions executes the pipeline.
- [ ] Successful executions reach the expected terminal state.
- [ ] Failed stages are reported.
- [ ] CloudWatch receives operational logs and metrics.
- [ ] Monitoring makes pipeline failures identifiable.

## 13. Security and operational practices

Apply security controls consistently across the architecture.

- Use IAM roles and least-privilege permissions.
- Protect credentials and secrets.
- Enable encryption for data at rest and in transit where supported.
- Restrict access to S3 and Redshift resources.
- Avoid committing Terraform state, credentials, or sensitive environment variables.
- Separate development configuration from other environments.
- Keep infrastructure changes under version control.
- Review Terraform plans before applying changes.

## 14. Cleanup

When the development environment is no longer required, review the Terraform plan for resource destruction.

From the development environment directory:

```bash
terraform plan -destroy
```

Review the resources that will be removed before executing:

```bash
terraform destroy
```

Confirm that any data or artifacts that must be retained have been backed up before destroying resources.

## 15. Related documentation

- `README.md` — Project overview, architecture scope, and technology stack.
- `docs/architecture.md` — Architecture components and data flow.
- `docs/architecture-diagram.md` — Architecture and dimensional model diagrams.
- `docs/data_model.md` — Fact table, dimensions, grain, and SCD Type 2 design.
- `docs/decisions.md` — Architecture Decision Records (ADRs).

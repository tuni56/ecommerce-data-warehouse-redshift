# Architectural Decision Log

This document records the key architectural decisions made during the design and implementation of the ecommerce data warehouse. Each entry explains the context, the options considered, the choice made, and the tradeoffs accepted.

---

## ADR-001 – Redshift Serverless vs. Provisioned Cluster

**Status:** Accepted  
**Date:** 2025

### Context
The warehouse needs to serve a mix of scheduled dbt runs, ad-hoc analyst queries, and periodic BI dashboard refreshes. Query load is variable and not always predictable at project inception.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| Redshift Serverless | Auto-scales, no cluster management, pay-per-use | Higher per-RPU cost at sustained load, less WLM control |
| Redshift Provisioned | Predictable cost at high utilization, fine-grained WLM | Requires capacity planning, idle cost during off-hours |

### Decision
**Redshift Serverless.** The variable, bursty nature of the workload makes serverless the better fit. Operational simplicity and automatic scaling outweigh the cost premium for this use case. If sustained query throughput grows significantly, migrating to a provisioned cluster is straightforward.

### Consequences
- No cluster resizing operations or maintenance windows.
- Cost is directly tied to query execution time; poorly written queries have an immediate cost impact — mitigated by dbt testing and query review practices.
- Maximum RPU capacity acts as a natural cost ceiling.

---

## ADR-002 – Star Schema vs. Data Vault

**Status:** Accepted  
**Date:** 2025

### Context
Choosing a modeling paradigm for the Gold layer. The primary consumers are business analysts using BI tools and SQL clients.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| Star Schema | Simple joins, BI-tool friendly, fast aggregation queries | Less flexible for unanticipated integration needs |
| Data Vault 2.0 | Highly flexible, auditable, handles multiple source systems | Complex to query, steep learning curve, slower initial delivery |
| One Big Table (OBT) | Simplest queries | No flexibility, massive duplication, hard to maintain |

### Decision
**Star schema.** The consumer base is analytics-focused rather than operational. Query simplicity, BI tool compatibility (QuickSight, Tableau), and shorter time-to-value make the star schema the right choice for this project's scope and audience.

### Consequences
- Schema changes require coordinated updates to dbt models and downstream queries.
- Adding a new subject area (e.g., returns, inventory) requires a new fact table rather than extending existing hubs — acceptable at this scale.

---

## ADR-003 – SCD Type 2 for Customer and Product Dimensions

**Status:** Accepted  
**Date:** 2025

### Context
Customer segments and product prices change over time. Analytical queries must be able to reproduce historical results accurately (e.g., "what was the revenue contribution of the Retail segment in Q1 2024?").

### Options Considered
| Option | Description | Tradeoff |
|---|---|---|
| SCD Type 1 (overwrite) | Always reflects current state | Loses history; historical reports change retroactively |
| SCD Type 2 (versioned rows) | New row per change, `valid_from`/`valid_to` | Increased storage and join complexity |
| SCD Type 6 (hybrid) | Combines Type 1, 2, and 3 | Highest complexity for marginal gain |

### Decision
**SCD Type 2 for `dim_customers` and `dim_products`.** Point-in-time accuracy is a core requirement for revenue reporting and customer lifetime value calculations. The storage overhead is acceptable given Redshift's columnar compression.

### Consequences
- Queries must filter on `is_current = TRUE` when only the current state is needed — documented in the sample queries and enforced in dbt exposures.
- dbt handles SCD Type 2 logic via the `snapshot` feature, keeping transformation code maintainable.

---

## ADR-004 – AWS Glue vs. Amazon EMR for ETL

**Status:** Accepted  
**Date:** 2025

### Context
The Silver layer requires data cleaning, type normalization, deduplication, and schema standardization before loading into Redshift.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| AWS Glue | Serverless, managed Spark, built-in connectors, job bookmarks | Less control over cluster config, higher per-DPU cost at extreme scale |
| Amazon EMR | Full Spark control, cost-efficient at scale, spot instances | Requires cluster management, longer setup time |
| Lambda + Pandas | Cheap for small files, simple | Not suitable for large datasets, 15-min execution limit |

### Decision
**AWS Glue.** The projected data volumes (<10TB) are well within Glue's operational sweet spot. Serverless execution, native S3/Redshift connectors, and job bookmarks (which prevent reprocessing of already-ingested data) reduce both operational burden and cost.

### Consequences
- If data volumes grow beyond ~10TB or ETL jobs require complex iterative processing, migration to EMR should be re-evaluated.
- Glue's DPU billing model means job efficiency directly impacts cost; Glue jobs are reviewed for partition pruning and early filtering.

---

## ADR-005 – S3 as Intermediate Staging Layer

**Status:** Accepted  
**Date:** 2025

### Context
Deciding whether to load data directly from source systems into Redshift or to stage through S3 first.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| Direct source → Redshift | Fewer moving parts | Tight coupling, no reprocessing capability, higher Redshift load |
| Source → S3 → Redshift | Decoupled, reprocessable, cost-efficient storage | Additional pipeline hop, more infrastructure to manage |

### Decision
**Source → S3 (Bronze) → S3 (Silver) → Redshift (Gold).** The S3-based medallion architecture decouples ingestion from transformation. Raw data is preserved indefinitely, enabling full reprocessing if transformation logic changes. S3 storage costs are significantly lower than Redshift storage, making it the right place to hold large volumes of unprocessed data.

### Consequences
- Full reprocessing from Bronze is always possible, which simplifies incident recovery.
- The `COPY` command (S3 → Redshift) is the most performant bulk-load mechanism available in Redshift, making the extra hop practically free at load time.

---

## ADR-006 – dbt Core vs. Managed dbt Cloud

**Status:** Accepted  
**Date:** 2025

### Context
The transformation layer requires a tool that enforces SQL modeling conventions, provides built-in testing, and generates documentation.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| dbt Core (self-hosted) | Free, full control, integrates with any orchestrator | Requires self-managed scheduling and CI setup |
| dbt Cloud | Managed IDE, scheduling, docs hosting | Subscription cost, vendor dependency |

### Decision
**dbt Core.** For a portfolio project with AWS Step Functions as the orchestrator, dbt Core provides all required functionality without additional cost. The team has full control over the execution environment and CI/CD integration.

### Consequences
- Scheduling and alerting are handled by Step Functions and CloudWatch rather than dbt Cloud's built-in scheduler.
- Documentation is generated locally (`dbt docs generate`) and can be hosted on S3 or served locally during development.

---

## ADR-007 – AWS Step Functions for Orchestration

**Status:** Accepted  
**Date:** 2025

### Context
The pipeline has sequential dependencies: raw ingestion must complete before Glue jobs run, which must complete before dbt transformations execute.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| AWS Step Functions | Native AWS, visual workflow, built-in error handling and retries | Less expressive for complex DAGs compared to Airflow |
| Apache Airflow (MWAA) | Powerful DAG authoring, large ecosystem | Higher cost, operational overhead |
| AWS EventBridge + Lambda | Simple triggers | Limited dependency management, harder to debug |

### Decision
**AWS Step Functions.** The pipeline topology is straightforward (linear with parallel Glue jobs per entity). Step Functions provides sufficient DAG expressiveness, native integration with Glue and Lambda, and built-in retry/failure handling — without the operational cost of a managed Airflow environment.

### Consequences
- Complex branching logic or dynamic task generation would require revisiting this decision in favor of MWAA.
- Step Functions state machine definitions are version-controlled in Terraform, ensuring reproducibility.

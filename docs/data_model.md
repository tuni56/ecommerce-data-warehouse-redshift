# Data Model – Ecommerce Star Schema

## Overview

The warehouse follows a **star schema** design optimized for analytical queries and BI tool consumption. All data flows from the Bronze and Silver layers into a set of conformed dimensions and a central fact table residing in Amazon Redshift Serverless (Gold layer).

The model is built and maintained using **dbt Core**, which handles SQL-based transformations, automated testing, and documentation generation.

---

## Schema Diagram

```mermaid
erDiagram
    fact_order_items ||--o{ dim_customers : "customer_key"
    fact_order_items ||--o{ dim_products : "product_key"
    fact_order_items ||--o{ dim_date : "order_date_key"
    fact_order_items ||--o{ dim_payment_methods : "payment_method_key"
    fact_order_items ||--o{ dim_shipment_status : "shipment_status_key"

    fact_order_items {
        bigint order_item_key PK
        bigint order_key
        bigint customer_key FK
        bigint product_key FK
        int order_date_key FK
        int payment_method_key FK
        int shipment_status_key FK
        int quantity
        decimal unit_price
        decimal discount_amount
        decimal total_amount
        timestamp created_at
    }

    dim_customers {
        bigint customer_key PK
        string customer_id NK
        string customer_name
        string email
        string country
        string segment
        date valid_from
        date valid_to
        boolean is_current
    }

    dim_products {
        bigint product_key PK
        string product_id NK
        string product_name
        string category
        string subcategory
        decimal list_price
        date valid_from
        date valid_to
        boolean is_current
    }

    dim_date {
        int date_key PK
        date date_value
        int year
        int quarter
        int month
        int day_of_week
        string month_name
        boolean is_weekend
    }

    dim_payment_methods {
        int payment_method_key PK
        string payment_method_name
        string payment_type
    }

    dim_shipment_status {
        int shipment_status_key PK
        string status_name
        string status_category
    }
```

---

## Fact Table

### `fact_order_items`

**Grain:** One row per order item (an individual product line within an order).

This grain was chosen to support product-level analysis without pre-aggregation, preventing double-counting when joining to multiple dimensions.

| Column | Type | Description |
|---|---|---|
| `order_item_key` | BIGINT | Surrogate primary key |
| `order_key` | BIGINT | Reference to the parent order |
| `customer_key` | BIGINT | FK → `dim_customers` |
| `product_key` | BIGINT | FK → `dim_products` |
| `order_date_key` | INT | FK → `dim_date` |
| `payment_method_key` | INT | FK → `dim_payment_methods` |
| `shipment_status_key` | INT | FK → `dim_shipment_status` |
| `quantity` | INT | Units ordered |
| `unit_price` | DECIMAL | Price per unit at time of sale |
| `discount_amount` | DECIMAL | Discount applied to the line item |
| `total_amount` | DECIMAL | `(unit_price × quantity) - discount_amount` |
| `created_at` | TIMESTAMP | Record creation timestamp |

**Distribution key:** `customer_key` — co-locates joins with `dim_customers`, the most frequent join target.  
**Sort key:** `order_date_key` — optimizes time-series queries and range scans on order dates.

---

## Dimension Tables

### `dim_customers` — SCD Type 2

Tracks the full history of customer attribute changes (e.g., segment reassignments, country updates). Each change produces a new row; the current record is identified by `is_current = TRUE`.

| Column | Type | Description |
|---|---|---|
| `customer_key` | BIGINT | Surrogate primary key |
| `customer_id` | VARCHAR | Natural key from source system |
| `customer_name` | VARCHAR | Full name |
| `email` | VARCHAR | Contact email |
| `country` | VARCHAR | Country of residence |
| `segment` | VARCHAR | Business segment (e.g., Retail, B2B) |
| `valid_from` | DATE | Start of this record's validity |
| `valid_to` | DATE | End of this record's validity (`NULL` if current) |
| `is_current` | BOOLEAN | `TRUE` for the active record |

**SCD Type 2 rationale:** enables point-in-time reporting — a revenue query can accurately reflect which customer segment was active at the time of the order.

---

### `dim_products` — SCD Type 2

Captures product attribute history, most critically price changes. Using surrogate keys ensures that historical fact rows remain linked to the correct product version.

| Column | Type | Description |
|---|---|---|
| `product_key` | BIGINT | Surrogate primary key |
| `product_id` | VARCHAR | Natural key from source system |
| `product_name` | VARCHAR | Display name |
| `category` | VARCHAR | Top-level product category |
| `subcategory` | VARCHAR | Product subcategory |
| `list_price` | DECIMAL | Catalogue price at the time this record was valid |
| `valid_from` | DATE | Start of validity |
| `valid_to` | DATE | End of validity (`NULL` if current) |
| `is_current` | BOOLEAN | `TRUE` for the active record |

---

### `dim_date`

A static date dimension pre-populated to cover the full analytical range of the business. Eliminates the need for date functions in analytical queries and enables consistent fiscal/calendar groupings.

| Column | Type | Description |
|---|---|---|
| `date_key` | INT | Surrogate key in `YYYYMMDD` format |
| `date_value` | DATE | Calendar date |
| `year` | INT | Calendar year |
| `quarter` | INT | Calendar quarter (1–4) |
| `month` | INT | Month number (1–12) |
| `day_of_week` | INT | Day of week (1 = Monday) |
| `month_name` | VARCHAR | Full month name |
| `is_weekend` | BOOLEAN | `TRUE` for Saturday and Sunday |

---

### `dim_payment_methods`

A small, slowly changing reference table for payment types. Updated manually when new payment methods are introduced.

| Column | Type | Description |
|---|---|---|
| `payment_method_key` | INT | Surrogate primary key |
| `payment_method_name` | VARCHAR | Display name (e.g., Credit Card, PayPal) |
| `payment_type` | VARCHAR | Broader category (e.g., Card, Digital Wallet, Bank Transfer) |

---

### `dim_shipment_status`

A static lookup table mapping raw shipment status codes to business-friendly labels and categories.

| Column | Type | Description |
|---|---|---|
| `shipment_status_key` | INT | Surrogate primary key |
| `status_name` | VARCHAR | Descriptive status (e.g., Delivered, In Transit) |
| `status_category` | VARCHAR | Aggregated category (e.g., Active, Completed, Exception) |

---

## Design Principles

- **Surrogate keys** are used on all tables to decouple the warehouse from source system key changes.
- **Natural keys** (`customer_id`, `product_id`) are preserved as non-key attributes for traceability and source reconciliation.
- **SCD Type 2** on customers and products enables accurate point-in-time analysis without storing snapshots of the fact table.
- **Conformed dimensions** (`dim_date`, `dim_customers`) are reusable across future fact tables, supporting a scalable multi-subject-area warehouse.
- **No many-to-many bridge tables** at this stage — the current grain eliminates the need for them and keeps query patterns simple.

---

## dbt Model Layers

| Layer | Models | Purpose |
|---|---|---|
| `staging` | `stg_orders`, `stg_customers`, `stg_products`, ... | Light transformations on Silver zone data: type casting, renaming, deduplication |
| `intermediate` | `int_order_items_enriched`, `int_customers_scd` | Business logic, SCD Type 2 processing, key generation |
| `marts` | `fact_order_items`, `dim_customers`, `dim_products`, ... | Final analytics-ready tables exposed to BI tools |

All mart models include dbt tests for `not_null`, `unique` (on primary keys), and `relationships` (referential integrity between fact and dimensions).

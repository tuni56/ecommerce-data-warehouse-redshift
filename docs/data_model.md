# Data Model – Ecommerce Data Warehouse (Redshift)

## Overview

This document describes the dimensional data model for the Ecommerce Data Warehouse implemented on Amazon Redshift Serverless.

The model is designed to support analytics and BI workloads with a focus on:
- Clear and explicit grain definitions
- Analyst-friendly star schema design
- Incremental and reliable data loading
- Long-term maintainability and extensibility

The data warehouse represents the **Gold layer** of a medallion architecture, with Amazon S3 serving as the system of record for raw and cleaned data.

---

## Modeling Principles

- Facts and dimensions are clearly separated
- Facts only join to dimensions (no dimension-to-dimension joins)
- Each fact table has a single, well-defined grain
- Surrogate keys are used for dimensions
- Business keys are preserved for traceability
- Schema design prioritizes usability over strict normalization

---

## Fact Tables

### `fact_orders`

**Business Purpose**  
Supports order-level analytics such as revenue, order outcomes, payments, and fulfillment performance.

**Grain**  
**One row per order (final state)**

Each record represents the final state of an order after all updates have been applied.

**Justification**
- Simplifies analytics and BI queries
- Avoids row explosion from order status changes
- Historical order state transitions can be modeled later using a separate event-based fact table if required

**Primary Identifiers**
- `order_id` (business key)
- `order_sk` (surrogate key, optional but recommended)

**Foreign Keys**
- `customer_sk`
- `payment_method_sk`
- `shipment_method_sk`
- `order_date_sk`

**Measures**
- `order_total_amount`
- `tax_amount`
- `shipping_amount`
- `discount_amount`
- `net_amount`

**Operational Attributes**
- `order_status`
- `payment_status`
- `created_at`
- `updated_at`

**Loading Notes**
- Incremental loads using MERGE / upsert logic
- Late-arriving updates handled via `updated_at`
- Idempotent transformations

---

### `fact_order_items`

**Business Purpose**  
Enables product-level, pricing, and quantity-based analytics.

**Grain**  
**One row per order item**

Each record represents a single product line within an order.

**Primary Identifiers**
- `order_item_id` (business key)

**Foreign Keys**
- `order_sk`
- `product_sk`

**Measures**
- `quantity`
- `unit_price`
- `item_total_amount`

**Notes**
- Separating order-level and item-level facts avoids grain confusion
- Supports detailed product, category, and pricing analysis

---

## Dimension Tables

### `dim_customers` (Slowly Changing Dimension – Type 2)

**Business Purpose**  
Captures customer attributes with historical tracking.

**Change Strategy**
SCD Type 2 is used to preserve historical changes that impact analytics.

**Business Key**
- `customer_id`

**Surrogate Key**
- `customer_sk`

**Attributes**
- `first_name`
- `last_name`
- `email`
- `customer_status`
- `country`
- `signup_date`

**SCD Fields**
- `effective_from`
- `effective_to`
- `is_current`

---

### `dim_products` (Slowly Changing Dimension – Type 1)

**Business Purpose**  
Stores current product attributes.

**Change Strategy**
SCD Type 1 (overwrite).

**Justification**
- Reduces complexity for the initial version
- Historical pricing analysis is supported via fact tables
- Can be evolved to SCD Type 2 if business requirements change

**Attributes**
- `product_id`
- `product_name`
- `category`
- `brand`
- `current_price`

---

### `dim_date`

**Business Purpose**  
Provides a standard calendar dimension for time-based analysis.

**Primary Key**
- `date_sk`

**Attributes**
- `date`
- `day`
- `month`
- `year`
- `week`
- `is_weekend`

---

### `dim_payment_method`

**Business Purpose**  
Standardizes payment-related attributes.

**Attributes**
- `payment_method_code`
- `provider`
- `payment_type` (e.g., card, wallet)

---

### `dim_shipment_method`

**Business Purpose**  
Standardizes shipment and fulfillment attributes.

**Attributes**
- `carrier`
- `service_level`
- `estimated_delivery_days`

---

## Schema Relationships

- Fact tables join only to dimension tables
- No joins between dimension tables
- Each fact table has a single, unambiguous grain
- Classic star schema optimized for analytics and BI tools

---

## Key Design Decisions

- **Star schema over snowflake schema**  
  Analyst usability and query safety are prioritized over strict normalization.

- **Selective use of SCD Type 2**  
  Only dimensions where historical changes provide analytical value are versioned.

- **Separate order and order item facts**  
  Order-level and item-level analytics require different grains and must not be mixed.

---

## Future Extensions

- Event-based fact table for order status transitions
- Additional dimensions (e.g., promotions, channels)
- Advanced data quality metrics and SLA tracking
- Evolution of selected dimensions to SCD Type 2 as needed

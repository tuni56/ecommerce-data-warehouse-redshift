## Data Model – Ecommerce Star Schema

The warehouse follows a star schema design optimized for analytics and
business consumption.

The main fact table is `fact_order_items`, with a grain of one row per
order item. This design prevents double counting and enables flexible
analysis by product, customer, and time.

Customer and product dimensions are modeled as Slowly Changing
Dimensions Type 2 to preserve historical accuracy.

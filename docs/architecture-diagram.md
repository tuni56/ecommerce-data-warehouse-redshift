# Architecture Diagram

## High-Level Data Flow

```mermaid
graph LR
    A[Source Systems<br/>OLTP Databases] -->|CDC/Batch Export| B[S3 Raw Zone<br/>Bronze Layer]
    B -->|AWS Glue ETL| C[S3 Staging Zone<br/>Silver Layer]
    C -->|COPY/Incremental Load| D[Redshift Serverless<br/>Gold Layer]
    D -->|SQL Queries| E[BI Tools<br/>QuickSight/Tableau]
    D -->|Ad-hoc Analysis| F[Data Analysts]
    
    style B fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style C fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style D fill:#8c4fff,stroke:#232f3e,stroke-width:2px,color:#fff
    style E fill:#232f3e,stroke:#ff9900,stroke-width:2px,color:#fff
```

## Detailed Architecture

```mermaid
graph TB
    subgraph "Data Sources"
        S1[Orders DB]
        S2[Customers DB]
        S3[Products DB]
        S4[Payments DB]
    end
    
    subgraph "Bronze Layer - Raw Data Lake"
        B1[S3: raw/orders/]
        B2[S3: raw/customers/]
        B3[S3: raw/products/]
        B4[S3: raw/payments/]
    end
    
    subgraph "Silver Layer - Cleaned & Standardized"
        G1[Glue Job:<br/>Clean Orders]
        G2[Glue Job:<br/>Clean Customers]
        G3[Glue Job:<br/>Clean Products]
        
        SG1[S3: staging/orders_cleaned/]
        SG2[S3: staging/customers_cleaned/]
        SG3[S3: staging/products_cleaned/]
    end
    
    subgraph "Gold Layer - Analytics Ready"
        subgraph "Redshift Serverless"
            DBT[dbt Transformations]
            
            F1[fact_order_items]
            D1[dim_customers<br/>SCD Type 2]
            D2[dim_products<br/>SCD Type 2]
            D3[dim_date]
            D4[dim_payment_methods]
            
            DBT --> F1
            DBT --> D1
            DBT --> D2
            DBT --> D3
            DBT --> D4
        end
    end
    
    subgraph "Consumption Layer"
        BI[Amazon QuickSight]
        SQL[SQL Clients]
        API[Data APIs]
    end
    
    subgraph "Orchestration & Monitoring"
        SF[Step Functions<br/>Workflow]
        CW[CloudWatch<br/>Logs & Metrics]
        SNS[SNS Alerts]
    end
    
    S1 --> B1
    S2 --> B2
    S3 --> B3
    S4 --> B4
    
    B1 --> G1
    B2 --> G2
    B3 --> G3
    
    G1 --> SG1
    G2 --> SG2
    G3 --> SG3
    
    SG1 --> DBT
    SG2 --> DBT
    SG3 --> DBT
    
    F1 --> BI
    D1 --> BI
    D2 --> BI
    
    F1 --> SQL
    F1 --> API
    
    SF -.->|Triggers| G1
    SF -.->|Triggers| G2
    SF -.->|Triggers| DBT
    
    G1 -.->|Logs| CW
    DBT -.->|Metrics| CW
    CW -.->|Alerts| SNS
    
    style B1 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style B2 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style B3 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style B4 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style SG1 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style SG2 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style SG3 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style F1 fill:#8c4fff,stroke:#232f3e,stroke-width:2px,color:#fff
    style D1 fill:#8c4fff,stroke:#232f3e,stroke-width:2px,color:#fff
    style D2 fill:#8c4fff,stroke:#232f3e,stroke-width:2px,color:#fff
    style D3 fill:#8c4fff,stroke:#232f3e,stroke-width:2px,color:#fff
    style D4 fill:#8c4fff,stroke:#232f3e,stroke-width:2px,color:#fff
    style DBT fill:#ff694b,stroke:#232f3e,stroke-width:2px,color:#fff
```

## Data Model - Star Schema

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

## Technology Stack Layers

```mermaid
graph TB
    subgraph "Presentation Layer"
        P1[Amazon QuickSight]
        P2[Tableau]
        P3[SQL Workbench]
    end
    
    subgraph "Analytics Layer"
        A1[Redshift Serverless<br/>Star Schema]
        A2[dbt Core<br/>Transformations & Tests]
    end
    
    subgraph "Processing Layer"
        PR1[AWS Glue<br/>ETL Jobs]
        PR2[Glue Crawlers<br/>Schema Discovery]
    end
    
    subgraph "Storage Layer"
        ST1[S3 - Raw Zone<br/>Parquet/JSON]
        ST2[S3 - Staging Zone<br/>Parquet]
    end
    
    subgraph "Infrastructure Layer"
        I1[Terraform<br/>IaC]
        I2[IAM Roles & Policies]
        I3[VPC & Security Groups]
    end
    
    subgraph "Orchestration Layer"
        O1[Step Functions]
        O2[EventBridge Rules]
    end
    
    subgraph "Monitoring Layer"
        M1[CloudWatch Logs]
        M2[CloudWatch Metrics]
        M3[SNS Notifications]
    end
    
    P1 --> A1
    P2 --> A1
    P3 --> A1
    
    A2 --> A1
    
    A1 --> PR1
    PR1 --> ST2
    PR2 --> ST1
    ST2 --> ST1
    
    O1 -.->|Orchestrates| PR1
    O1 -.->|Orchestrates| A2
    O2 -.->|Triggers| O1
    
    PR1 -.->|Logs| M1
    A1 -.->|Metrics| M2
    M2 -.->|Alerts| M3
    
    I1 -.->|Provisions| A1
    I1 -.->|Provisions| PR1
    I1 -.->|Provisions| ST1
    I1 -.->|Provisions| I2
    I1 -.->|Provisions| I3
```

## Deployment Pipeline

```mermaid
graph LR
    A[Developer] -->|git push| B[GitHub]
    B -->|Webhook| C[GitHub Actions]
    
    C -->|terraform validate| D{Validation}
    D -->|Pass| E[terraform plan]
    D -->|Fail| Z[Notify Developer]
    
    E -->|Review| F{Approve?}
    F -->|Yes| G[terraform apply]
    F -->|No| Z
    
    G -->|Deploy| H[Dev Environment]
    H -->|Promote| I[Staging Environment]
    I -->|Promote| J[Production Environment]
    
    H -.->|dbt test| K[Data Quality Checks]
    I -.->|dbt test| K
    J -.->|dbt test| K
    
    K -->|Fail| Z
    
    style C fill:#2088ff,stroke:#232f3e,stroke-width:2px,color:#fff
    style G fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style K fill:#ff694b,stroke:#232f3e,stroke-width:2px,color:#fff
```

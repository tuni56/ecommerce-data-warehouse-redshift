#!/usr/bin/env python3
"""
Generate sample ecommerce data for the data warehouse
"""
import json
import random
from datetime import datetime, timedelta
from pathlib import Path
import csv

# Configuration
NUM_CUSTOMERS = 1000
NUM_PRODUCTS = 200
NUM_ORDERS = 5000
OUTPUT_DIR = Path("data/raw")

# Sample data
FIRST_NAMES = ["John", "Jane", "Michael", "Sarah", "David", "Emily", "Robert", "Lisa"]
LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
COUNTRIES = ["USA", "Canada", "UK", "Germany", "France", "Spain", "Italy", "Australia"]
CATEGORIES = ["Electronics", "Clothing", "Home & Garden", "Sports", "Books", "Toys"]
PAYMENT_METHODS = ["credit_card", "debit_card", "paypal", "bank_transfer"]
SHIPMENT_STATUSES = ["pending", "shipped", "delivered", "cancelled"]

def generate_customers():
    """Generate customer data"""
    customers = []
    for i in range(1, NUM_CUSTOMERS + 1):
        customer = {
            "customer_id": f"CUST{i:06d}",
            "first_name": random.choice(FIRST_NAMES),
            "last_name": random.choice(LAST_NAMES),
            "email": f"customer{i}@example.com",
            "country": random.choice(COUNTRIES),
            "signup_date": (datetime.now() - timedelta(days=random.randint(1, 730))).strftime("%Y-%m-%d"),
            "customer_status": random.choice(["active", "inactive"]),
        }
        customers.append(customer)
    return customers

def generate_products():
    """Generate product data"""
    products = []
    for i in range(1, NUM_PRODUCTS + 1):
        category = random.choice(CATEGORIES)
        product = {
            "product_id": f"PROD{i:06d}",
            "product_name": f"{category} Item {i}",
            "category": category,
            "brand": f"Brand {random.randint(1, 20)}",
            "current_price": round(random.uniform(10, 500), 2),
        }
        products.append(product)
    return products

def generate_orders(customers, products):
    """Generate order and order items data"""
    orders = []
    order_items = []
    
    for i in range(1, NUM_ORDERS + 1):
        order_date = datetime.now() - timedelta(days=random.randint(0, 365))
        customer = random.choice(customers)
        
        order = {
            "order_id": f"ORD{i:08d}",
            "customer_id": customer["customer_id"],
            "order_date": order_date.strftime("%Y-%m-%d"),
            "order_status": random.choice(["completed", "pending", "cancelled"]),
            "payment_method": random.choice(PAYMENT_METHODS),
            "shipment_status": random.choice(SHIPMENT_STATUSES),
            "created_at": order_date.isoformat(),
            "updated_at": (order_date + timedelta(hours=random.randint(1, 48))).isoformat(),
        }
        orders.append(order)
        
        # Generate 1-5 items per order
        num_items = random.randint(1, 5)
        for j in range(1, num_items + 1):
            product = random.choice(products)
            quantity = random.randint(1, 3)
            unit_price = product["current_price"]
            
            order_item = {
                "order_item_id": f"{order['order_id']}-{j:02d}",
                "order_id": order["order_id"],
                "product_id": product["product_id"],
                "quantity": quantity,
                "unit_price": unit_price,
                "item_total_amount": round(quantity * unit_price, 2),
            }
            order_items.append(order_item)
    
    return orders, order_items

def save_to_csv(data, filename):
    """Save data to CSV file"""
    if not data:
        return
    
    filepath = OUTPUT_DIR / filename
    filepath.parent.mkdir(parents=True, exist_ok=True)
    
    with open(filepath, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=data[0].keys())
        writer.writeheader()
        writer.writerows(data)
    
    print(f"✓ Generated {len(data)} records in {filename}")

def main():
    print("Generating sample ecommerce data...")
    print()
    
    # Generate data
    customers = generate_customers()
    products = generate_products()
    orders, order_items = generate_orders(customers, products)
    
    # Save to CSV
    save_to_csv(customers, "customers/customers.csv")
    save_to_csv(products, "products/products.csv")
    save_to_csv(orders, "orders/orders.csv")
    save_to_csv(order_items, "order_items/order_items.csv")
    
    print()
    print(f"✓ Data generation complete!")
    print(f"  Output directory: {OUTPUT_DIR.absolute()}")
    print()
    print("Next steps:")
    print("  1. Upload to S3: aws s3 sync data/raw/ s3://<bucket-name>/raw/")
    print("  2. Run Glue crawler to catalog the data")

if __name__ == "__main__":
    main()

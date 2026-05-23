-- SQL Lakehouse Design: Bronze, Silver, Gold Layers

-- This script demonstrates the creation and population of Bronze, Silver, and Gold layers
-- using standard SQL. You can execute these commands in any SQL database environment
-- (e.g., PostgreSQL, MySQL, SQL Server, Databricks SQL, Snowflake).

-- 1. Bronze Layer: Raw Data Ingestion
-- This layer holds the raw, untransformed data directly from the source. Data types
-- are often kept as strings to preserve the original format before cleaning.

-- Create Bronze Customers Table
CREATE TABLE bronze_customers (
    customer_id VARCHAR(10),
    customer_name VARCHAR(100),
    email VARCHAR(100),
    city VARCHAR(50)
);

-- Insert raw data into Bronze Customers
INSERT INTO bronze_customers (customer_id, customer_name, email, city) VALUES
('C001', 'Alice Smith', 'alice.s@example.com', 'New York'),
('C002', 'Bob Johnson', 'bob.j@example.com', 'Los Angeles'),
('C003', 'Charlie Brown', 'charlie.b@example.com', 'Chicago'),
('C004', 'Diana Prince', 'diana.p@example.com', 'Miami'),
('C005', 'Eve Adams', 'eve.a@example.com', 'Houston');

-- Create Bronze Products Table
CREATE TABLE bronze_products (
    product_id VARCHAR(10),
    product_name VARCHAR(100),
    category VARCHAR(50),
    price VARCHAR(20) -- Raw price might be string
);

-- Insert raw data into Bronze Products
INSERT INTO bronze_products (product_id, product_name, category, price) VALUES
('P001', 'Laptop', 'Electronics', '1200.00'),
('P002', 'Mouse', 'Electronics', '25.00'),
('P003', 'Keyboard', 'Electronics', '75.00'),
('P004', 'Monitor', 'Electronics', '300.00'),
('P005', 'Webcam', 'Electronics', '50.00');

-- Create Bronze Orders Table
CREATE TABLE bronze_orders (
    order_id VARCHAR(10),
    customer_id VARCHAR(10),
    order_date VARCHAR(20), -- Raw date might be string
    status VARCHAR(50)
);

-- Insert raw data into Bronze Orders
INSERT INTO bronze_orders (order_id, customer_id, order_date, status) VALUES
('O001', 'C001', '2023-01-10', 'Completed'),
('O002', 'C002', '2023-01-11', 'Pending'),
('O003', 'C001', '2023-01-12', 'Completed'),
('O004', 'C003', '2023-01-13', 'Shipped'),
('O005', 'C004', '2023-01-14', 'Completed');

-- Create Bronze Order Items Table
CREATE TABLE bronze_order_items (
    order_item_id VARCHAR(10),
    order_id VARCHAR(10),
    product_id VARCHAR(10),
    quantity VARCHAR(10), -- Raw quantity might be string
    unit_price VARCHAR(20) -- Raw price might be string
);

-- Insert raw data into Bronze Order Items
INSERT INTO bronze_order_items (order_item_id, order_id, product_id, quantity, unit_price) VALUES
('OI001', 'O001', 'P001', '1', '1200.00'),
('OI002', 'O001', 'P002', '2', '25.00'),
('OI003', 'O002', 'P003', '1', '75.00'),
('OI004', 'O003', 'P004', '1', '300.00'),
('OI005', 'O004', 'P005', '3', '50.00');

-- Create Bronze Payments Table
CREATE TABLE bronze_payments (
    payment_id VARCHAR(10),
    order_id VARCHAR(10),
    payment_date VARCHAR(20), -- Raw date might be string
    amount VARCHAR(20), -- Raw amount might be string
    payment_method VARCHAR(50)
);

-- Insert raw data into Bronze Payments
INSERT INTO bronze_payments (payment_id, order_id, payment_date, amount, payment_method) VALUES
('PM001', 'O001', '2023-01-10', '1250.00', 'Credit Card'),
('PM002', 'O003', '2023-01-12', '300.00', 'Debit Card'),
('PM003', 'O004', '2023-01-13', '150.00', 'PayPal'),
('PM004', 'O005', '2023-01-14', '500.00', 'Credit Card'),
('PM005', 'O002', '2023-01-11', '75.00', 'Credit Card');


-- 2. Silver Layer: Cleaned and Conformed Data
-- This layer applies basic transformations, data type conversions, and standardization.
-- We'll create a conformed 'silver_orders_details' table by joining relevant bronze tables,
-- casting data types, and calculating derived fields.

CREATE TABLE silver_orders_details (
    order_id VARCHAR(10),
    customer_id VARCHAR(10),
    customer_name VARCHAR(100),
    order_date DATE,
    product_id VARCHAR(10),
    product_name VARCHAR(100),
    category VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10, 2),
    total_item_price DECIMAL(10, 2),
    order_status VARCHAR(50),
    payment_method VARCHAR(50),
    payment_amount DECIMAL(10, 2),
    payment_date DATE
);

INSERT INTO silver_orders_details (
    order_id, customer_id, customer_name, order_date,
    product_id, product_name, category, quantity, unit_price, total_item_price,
    order_status, payment_method, payment_amount, payment_date
)
SELECT
    o.order_id,
    c.customer_id,
    c.customer_name,
    CAST(o.order_date AS DATE) AS order_date,
    p.product_id,
    p.product_name,
    p.category,
    CAST(oi.quantity AS INT) AS quantity,
    CAST(oi.unit_price AS DECIMAL(10, 2)) AS unit_price,
    CAST(oi.quantity AS INT) * CAST(oi.unit_price AS DECIMAL(10, 2)) AS total_item_price,
    o.status AS order_status,
    pm.payment_method,
    CAST(pm.amount AS DECIMAL(10, 2)) AS payment_amount,
    CAST(pm.payment_date AS DATE) AS payment_date
FROM
    bronze_orders o
JOIN
    bronze_customers c ON o.customer_id = c.customer_id
JOIN
    bronze_order_items oi ON o.order_id = oi.order_id
JOIN
    bronze_products p ON oi.product_id = p.product_id
LEFT JOIN -- Use LEFT JOIN for payments as an order might not have a payment recorded yet
    bronze_payments pm ON o.order_id = pm.order_id;


-- 3. Gold Layer: Curated and Aggregated Data
-- This layer provides highly refined, aggregated data for business intelligence and reporting.
-- We'll create a summary table for monthly sales by category.

CREATE TABLE gold_monthly_sales_by_category (
    sales_month DATE,
    category VARCHAR(50),
    total_sales DECIMAL(18, 2),
    total_orders INT,
    unique_customers INT
);

INSERT INTO gold_monthly_sales_by_category (
    sales_month, category, total_sales, total_orders, unique_customers
)
SELECT
    DATE_TRUNC('month', order_date) AS sales_month, -- Use appropriate date truncation for your SQL dialect (e.g., TRUNC(order_date, 'MM') for Oracle, DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) for SQL Server)
    category,
    SUM(total_item_price) AS total_sales,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM
    silver_orders_details
GROUP BY
    DATE_TRUNC('month', order_date),
    category
ORDER BY
    sales_month, category;

-- Example Query on Gold Layer
SELECT * FROM gold_monthly_sales_by_category;

-- Example Query on Silver Layer
SELECT
    customer_name,
    order_id,
    order_date,
    SUM(total_item_price) AS order_total
FROM
    silver_orders_details
GROUP BY
    customer_name, order_id, order_date
ORDER BY
    order_date DESC;

-- Optional: Clean up tables (uncomment and execute if you want to drop the created tables)
-- DROP TABLE IF EXISTS gold_monthly_sales_by_category;
-- DROP TABLE IF EXISTS silver_orders_details;
-- DROP TABLE IF EXISTS bronze_customers;
-- DROP TABLE IF EXISTS bronze_products;
-- DROP TABLE IF EXISTS bronze_orders;
-- DROP TABLE IF EXISTS bronze_order_items;
-- DROP TABLE IF EXISTS bronze_payments;

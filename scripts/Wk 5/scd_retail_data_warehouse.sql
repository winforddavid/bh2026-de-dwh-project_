-- SQL Notebook for Online Retail Data Warehouse Design

-- 1. Create Dimension Tables

-- DimProduct
CREATE TABLE DimProduct (
    product_key SERIAL PRIMARY KEY, -- Surrogate key
    product_id VARCHAR(50) NOT NULL UNIQUE,    -- Natural key
    product_name VARCHAR(255),
    product_category VARCHAR(100),
    unit_price DECIMAL(10, 2)
);

-- DimCustomer
CREATE TABLE DimCustomer (
    customer_key SERIAL PRIMARY KEY, -- Surrogate key
    customer_id VARCHAR(50) NOT NULL UNIQUE,    -- Natural key
    customer_name VARCHAR(255),
    customer_email VARCHAR(255),
    customer_city VARCHAR(100),
    customer_country VARCHAR(100)
);

-- DimDate
-- This table is typically pre-populated for a wide range of dates.
-- For this exercise, we'll populate it with dates from our sample data.
CREATE TABLE DimDate (
    date_key INT PRIMARY KEY, -- YYYYMMDD format
    full_date DATE NOT NULL UNIQUE,
    day_of_week INT, -- 0=Sunday, 1=Monday...
    day_name VARCHAR(10),
    month INT,
    month_name VARCHAR(10),
    quarter INT,
    year INT
);

-- 2. Create Fact Table

-- FactSales
CREATE TABLE FactSales (
    sale_key SERIAL PRIMARY KEY,
    date_key INT NOT NULL,
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    quantity INT,
    total_amount DECIMAL(10, 2),
    FOREIGN KEY (date_key) REFERENCES DimDate(date_key),
    FOREIGN KEY (customer_key) REFERENCES DimCustomer(customer_key),
    FOREIGN KEY (product_key) REFERENCES DimProduct(product_key)
);

-- 3. Load Data into Dimension Tables

-- Populate DimProduct from distinct product information in the raw data
INSERT INTO DimProduct (product_id, product_name, product_category, unit_price)
SELECT DISTINCT product_id, product_name, product_category, unit_price
FROM (VALUES
    ('P001', 'Laptop', 'Electronics', 1200.00),
    ('P003', 'Mouse', 'Electronics', 25.00),
    ('P002', 'Keyboard', 'Electronics', 75.00),
    ('P004', 'Desk Chair', 'Furniture', 150.00),
    ('P005', 'Coffee Maker', 'Home Goods', 80.00),
    ('P006', 'Monitor', 'Electronics', 300.00),
    ('P007', 'Headphones', 'Electronics', 100.00)
) AS raw_products(product_id, product_name, product_category, unit_price)
ON CONFLICT (product_id) DO NOTHING; -- Prevents duplicate inserts if run multiple times

-- Populate DimCustomer from distinct customer information in the raw data
INSERT INTO DimCustomer (customer_id, customer_name, customer_email, customer_city, customer_country)
SELECT DISTINCT customer_id, customer_name, customer_email, customer_city, customer_country
FROM (VALUES
    ('C001', 'Alice Smith', 'alice.s@example.com', 'New York', 'USA'),
    ('C002', 'Bob Johnson', 'bob.j@example.com', 'London', 'UK'),
    ('C003', 'Charlie Brown', 'charlie.b@example.com', 'Paris', 'France'),
    ('C004', 'Diana Prince', 'diana.p@example.com', 'Berlin', 'Germany'),
    ('C005', 'Eve Adams', 'eve.a@example.com', 'Tokyo', 'Japan'),
    ('C006', 'Frank White', 'frank.w@example.com', 'Sydney', 'Australia')
) AS raw_customers(customer_id, customer_name, customer_email, customer_city, customer_country)
ON CONFLICT (customer_id) DO NOTHING;

-- Populate DimDate from distinct dates found in the raw data
INSERT INTO DimDate (date_key, full_date, day_of_week, day_name, month, month_name, quarter, year)
SELECT DISTINCT
    CAST(REPLACE(order_date, '-', '') AS INT) AS date_key,
    order_date::DATE AS full_date,
    EXTRACT(DOW FROM order_date::DATE) AS day_of_week, -- PostgreSQL specific: 0=Sunday, 1=Monday...
    TO_CHAR(order_date::DATE, 'Day') AS day_name, -- PostgreSQL specific
    EXTRACT(MONTH FROM order_date::DATE) AS month,
    TO_CHAR(order_date::DATE, 'Month') AS month_name, -- PostgreSQL specific
    EXTRACT(QUARTER FROM order_date::DATE) AS quarter,
    EXTRACT(YEAR FROM order_date::DATE) AS year
FROM (VALUES
    ('2023-01-05'), ('2023-01-06'), ('2023-01-07'), ('2023-01-08'), ('2023-01-09'),
    ('2023-01-10'), ('2023-01-11'), ('2023-01-12'), ('2023-01-13'), ('2023-01-14'),
    ('2023-01-15')
) AS raw_dates(order_date)
ON CONFLICT (full_date) DO NOTHING;

-- 4. Load Data into Fact Table

-- Populate FactSales by joining raw sales data with dimension tables to get surrogate keys
INSERT INTO FactSales (date_key, customer_key, product_key, order_id, quantity, total_amount)
SELECT
    dd.date_key,
    dc.customer_key,
    dp.product_key,
    rs.order_id,
    rs.quantity,
    rs.unit_price * rs.quantity AS total_amount
FROM (VALUES
    ('1001', '2023-01-05', 'C001', 'Alice Smith', 'alice.s@example.com', 'New York', 'USA', 'P001', 'Laptop', 'Electronics', 1200.00, 1),
    ('1002', '2023-01-05', 'C002', 'Bob Johnson', 'bob.j@example.com', 'London', 'UK', 'P003', 'Mouse', 'Electronics', 25.00, 2),
    ('1003', '2023-01-06', 'C001', 'Alice Smith', 'alice.s@example.com', 'New York', 'USA', 'P002', 'Keyboard', 'Electronics', 75.00, 1),
    ('1004', '2023-01-07', 'C003', 'Charlie Brown', 'charlie.b@example.com', 'Paris', 'France', 'P004', 'Desk Chair', 'Furniture', 150.00, 1),
    ('1005', '2023-01-07', 'C002', 'Bob Johnson', 'bob.j@example.com', 'London', 'UK', 'P001', 'Laptop', 'Electronics', 1200.00, 1),
    ('1006', '2023-01-08', 'C004', 'Diana Prince', 'diana.p@example.com', 'Berlin', 'Germany', 'P005', 'Coffee Maker', 'Home Goods', 80.00, 1),
    ('1007', '2023-01-08', 'C001', 'Alice Smith', 'alice.s@example.com', 'New York', 'USA', 'P003', 'Mouse', 'Electronics', 25.00, 3),
    ('1008', '2023-01-09', 'C005', 'Eve Adams', 'eve.a@example.com', 'Tokyo', 'Japan', 'P006', 'Monitor', 'Electronics', 300.00, 1),
    ('1009', '2023-01-09', 'C003', 'Charlie Brown', 'charlie.b@example.com', 'Paris', 'France', 'P002', 'Keyboard', 'Electronics', 75.00, 2),
    ('1010', '2023-01-10', 'C004', 'Diana Prince', 'diana.p@example.com', 'Berlin', 'Germany', 'P001', 'Laptop', 'Electronics', 1200.00, 1),
    ('1011', '2023-01-10', 'C002', 'Bob Johnson', 'bob.j@example.com', 'London', 'UK', 'P005', 'Coffee Maker', 'Home Goods', 80.00, 1),
    ('1012', '2023-01-11', 'C001', 'Alice Smith', 'alice.s@example.com', 'New York', 'USA', 'P004', 'Desk Chair', 'Furniture', 150.00, 1),
    ('1013', '2023-01-11', 'C005', 'Eve Adams', 'eve.a@example.com', 'Tokyo', 'Japan', 'P003', 'Mouse', 'Electronics', 25.00, 1),
    ('1014', '2023-01-12', 'C006', 'Frank White', 'frank.w@example.com', 'Sydney', 'Australia', 'P007', 'Headphones', 'Electronics', 100.00, 1),
    ('1015', '2023-01-12', 'C003', 'Charlie Brown', 'charlie.b@example.com', 'Paris', 'France', 'P006', 'Monitor', 'Electronics', 300.00, 1),
    ('1016', '2023-01-13', 'C004', 'Diana Prince', 'diana.p@example.com', 'Berlin', 'Germany', 'P002', 'Keyboard', 'Electronics', 75.00, 1),
    ('1017', '2023-01-13', 'C001', 'Alice Smith', 'alice.s@example.com', 'New York', 'USA', 'P007', 'Headphones', 'Electronics', 100.00, 2),
    ('1018', '2023-01-14', 'C002', 'Bob Johnson', 'bob.j@example.com', 'London', 'UK', 'P004', 'Desk Chair', 'Furniture', 150.00, 1),
    ('1019', '2023-01-14', 'C005', 'Eve Adams', 'eve.a@example.com', 'Tokyo', 'Japan', 'P001', 'Laptop', 'Electronics', 1200.00, 1),
    ('1020', '2023-01-15', 'C006', 'Frank White', 'frank.w@example.com', 'Sydney', 'Australia', 'P005', 'Coffee Maker', 'Home Goods', 80.00, 1)
) AS rs(order_id, order_date, customer_id, customer_name, customer_email, customer_city, customer_country, product_id, product_name, product_category, unit_price, quantity)
JOIN DimDate dd ON CAST(REPLACE(rs.order_date, '-', '') AS INT) = dd.date_key
JOIN DimCustomer dc ON rs.customer_id = dc.customer_id
JOIN DimProduct dp ON rs.product_id = dp.product_id;


-- 5. Example Analytical Queries

-- Total sales by product category
SELECT
    dp.product_category,
    SUM(fs.total_amount) AS total_sales_amount,
    SUM(fs.quantity) AS total_quantity_sold
FROM FactSales fs
JOIN DimProduct dp ON fs.product_key = dp.product_key
GROUP BY dp.product_category
ORDER BY total_sales_amount DESC;

-- Monthly sales by customer country
SELECT
    dd.year,
    dd.month_name,
    dc.customer_country,
    SUM(fs.total_amount) AS total_sales_amount
FROM FactSales fs
JOIN DimDate dd ON fs.date_key = dd.date_key
JOIN DimCustomer dc ON fs.customer_key = dc.customer_key
GROUP BY dd.year, dd.month_name, dc.customer_country
ORDER BY dd.year, dd.month, total_sales_amount DESC;

-- Top 5 customers by total spend
SELECT
    dc.customer_name,
    dc.customer_email,
    SUM(fs.total_amount) AS total_spend
FROM FactSales fs
JOIN DimCustomer dc ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_name, dc.customer_email
ORDER BY total_spend DESC
LIMIT 5;
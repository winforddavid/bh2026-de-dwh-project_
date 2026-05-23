-- Databricks notebook source
-- MAGIC %md
-- MAGIC    
-- MAGIC # Week 3 — SQL (Olist) 
-- MAGIC *Catalog/Schema fixed to `bh2026-winford-uc-dev.bricks_hub_olist`*
-- MAGIC *Each step below is isolated in its own cell so students see results per query.*

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Initialisation & Setup

-- COMMAND ----------

-- Set catalog & schema (explicit)
USE CATALOG `bh2026-winford-uc-dev`;
USE SCHEMA bricks_hub_olist;
SELECT current_catalog() AS current_catalog, current_schema() AS current_schema;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Create Database

-- COMMAND ----------

-- DROP DATABASE IF EXISTS `bh2026-winford-uc-dev`.bricks_hub_olist CASCADE
-- CREATE DATABASE IF NOT EXISTS bricks_hub_olist
-- USE DATABASE bricks_hub_olist

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Identify and List the full path for all the BLOB files in the Olist Volume stored in MS ADLS ![Gen2](![path](![path](path)))
-- MAGIC /Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist
-- MAGIC

-- COMMAND ----------

-- DBTITLE 1,Cell 10
-- MAGIC %fs ls /Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Create all the Bronze Layer Tables using dbutils, main SQL clauses and full path names
-- MAGIC \
-- MAGIC <img src="./Main SQL CLause_1778679852526.png" width="700" />

-- COMMAND ----------

DROP TABLE IF EXISTS bronze_orders;

-- COMMAND ----------

CREATE OR REPLACE TABLE bronze_orders AS
SELECT *
FROM read_files(
    'dbfs:/Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist/olist_orders_dataset.csv',
    format => 'csv',
    header => true,
    inferschema => true
);

-- COMMAND ----------

SELECT * FRom bronze_orders
LIMIT 5;

-- COMMAND ----------

DROP TABLE IF EXISTS bronze_customers;

-- COMMAND ----------

CREATE OR REPLACE TABLE bronze_customers AS
SELECT *
FROM read_files(
    'dbfs:/Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist/olist_customers_dataset.csv',
    format => 'csv',
    header => true,
    inferSchema => true
);

-- COMMAND ----------

SELECT * FROM bronze_customers
LIMIT 10;

-- COMMAND ----------

DROP TABLE IF EXISTS bronze_order_items;

-- COMMAND ----------

CREATE OR REPLACE TABLE bronze_order_items AS
SELECT *
FROM read_files(
    'dbfs:/Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist/olist_order_items_dataset.csv',
    format => 'csv',
    header => true,
    inferSchema => true
);

-- COMMAND ----------

SELECT * FROM bronze_order_items
LIMIT 5;

-- COMMAND ----------

DROP TABLE IF EXISTS bronze_payments;

-- COMMAND ----------

CREATE OR REPLACE TABLE bronze_payments AS
FROM read_files (
    'dbfs:/Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist/olist_order_payments_dataset.csv',
    format => 'csv',
    header => true,
    inferSchema => true
);

-- COMMAND ----------

SELECT * FROM bronze_payments
LIMIT 5;

-- COMMAND ----------

DROP TABLE IF EXISTS bronze_products;

-- COMMAND ----------

CREATE OR REPLACE TABLE bronze_products AS
SELECT *
FROM read_files(
  'dbfs:/Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist/olist_products_dataset.csv',
  format => 'csv',
  header => true,
  inferSchema => false
);


-- COMMAND ----------

SELECT * FROM bronze_products
LIMIT 10;

-- COMMAND ----------

DROP TABLE IF EXISTS bronze_sellers;

-- COMMAND ----------

CREATE OR REPLACE TABLE bronze_sellers AS
SELECT *
FROM read_files(
  'dbfs:/Volumes/bh2026-winford-uc-dev/bricks_hub_olist/olist/olist_sellers_dataset.csv',
  format => 'csv',
  header => true,
  inferSchema => false
);


-- COMMAND ----------

SELECT * FROM bronze_sellers
LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Create Silver Layer Tables

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Create all the Silver Layer Tables using SQL clauses, Functions and CTEs
-- MAGIC

-- COMMAND ----------

DROP TABLE IF EXISTS silver_orders;

-- COMMAND ----------

CREATE OR REPLACE TABLE silver_orders AS
SELECT
    order_id,
    customer_id,
    lower(order_status) As order_status, 

    -- enforce and format the datetimestamp fields as follows: 

    to_timestamp(order_purchase_timestamp, 'dd/MM/yyyy HH:mm')
    AS order_purchase_ts,

    to_timestamp(order_approved_at, 'dd/MM/yyyy HH:mm')
    AS order_approved_ts,

    to_timestamp(order_delivered_carrier_date, 'dd/MM/yyyy HH:mm')
    AS order_delivered_customer_ts,

    to_timestamp(order_estimated_delivery_date, 'dd/MM/yyyy HH:mm')
    AS order_estimated_delivery_ts

    FROM bronze_orders;

-- COMMAND ----------

SELECT * FROM silver_orders
LIMIT 20;

-- COMMAND ----------

DROP TABLE IF EXISTS silver_customers;

-- COMMAND ----------

CREATE OR REPLACE TABLE silver_customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    upper(customer_city) AS customer_city,
    upper(customer_state) AS customer_state
FROM bronze_customers;

-- COMMAND ----------

SELECT * FROM silver_customers
LIMIT 20;

-- COMMAND ----------

DROP TABLE IF EXISTS silver_order_items;

-- COMMAND ----------

-- Create Silver Order Items Table from Bronze Order Items
CREATE OR REPLACE TABLE silver_order_items AS
SELECT
    order_id,
    CAST(order_item_id AS INT) AS order_item_id,
    product_id,
    seller_id,
    CAST(price AS DOUBLE) AS price,
    CAST(freight_value AS DOUBLE) AS freight_value
FROM bronze_order_items;

-- COMMAND ----------

SELECT * FROM silver_order_items
LIMIT 20;

-- COMMAND ----------

-- DROP TABLE IF EXISTS silver_payments;

-- COMMAND ----------

-- create silver payments table from bronze payments table
CREATE OR REPLACE TABLE silver_payments AS
SELECT
    order_id,
    CAST(payment_sequential AS INT) AS payment_sequential,
    lower(payment_type) AS payment_type,
    CAST(payment_installments AS INT) AS payment_installments,
    CAST(payment_value AS DOUBLE) AS payment_value
FROM bronze_payments;

-- COMMAND ----------

SELECT * FROM silver_payments
LIMIT 20;

-- COMMAND ----------

DROP TABLE IF EXISTS silver_products;

-- COMMAND ----------

CREATE OR REPLACE TABLE silver_products AS
SELECT
    product_id,
    lower(product_category_name) AS product_category_name
FROM bronze_products;

-- COMMAND ----------

SELECT * FROM silver_products
LIMIT 25;

-- COMMAND ----------

DROP TABLE IF EXISTS silver_sellers;

-- COMMAND ----------

CREATE OR REPLACE TABLE silver_sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix,
    upper(seller_city) AS seller_city,
    upper(seller_state) AS seller_state
FROM bronze_sellers;

-- COMMAND ----------

SELECT * FROM silver_sellers
LIMIT 25;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Initial Data and Quality Checks

-- COMMAND ----------

-- QA & identify missing FK's or ID fields Y/N? from Silver Orders
SELECT * FROM silver_orders 
LIMIT 5;

SELECT 'any_rows_missing_ids Y/N?' AS id_checks, COUNT(*) AS no_rows_missing_ids
FROM silver_orders
WHERE order_id IS NULL;

-- COMMAND ----------

-- QA & identify missing FK's or ID fields Y/N? from Silver Customers
SELECT * FROM silver_customers
LIMIT 5;

SELECT 'any_rows_customerid_fields_missing_ids' AS customerid_check, COUNT(*) AS no_customerid_rows_missing_ids
FROM silver_customers
WHERE customer_id IS NULL;

-- COMMAND ----------

-- QA & identify missing FK's or ID fields Y/N? from Silver Order Items
SELECT * FROM silver_order_items
LIMIT 5;

SELECT 'any_order_items_rows_wo_fks' AS rows_missing_order_items_id, COUNT(*) AS no_orderitems_missing_ids
FROM silver_order_items
WHERE order_id IS NULL;

-- COMMAND ----------

-- QA: status of distribution types
SELECT * FROM silver_orders
LIMIT 5;

SELECT order_status, COUNT(*) AS cnt
FROM silver_orders
GROUP BY order_status ORDER BY cnt DESC;


-- COMMAND ----------

-- Checks on how many delivered dates were earlier than their approved order dates?
SELECT * FROM silver_orders
LIMIT 5;

SELECT COUNT(*) AS naughty_rows
FROM silver_orders
WHERE order_delivered_customer_ts IS NOT NULL 
    AND order_approved_ts IS NOT NULL
    AND order_delivered_customer_ts < order_approved_ts;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Excercises

-- COMMAND ----------

-- EX 1: Top 5 most recent approved orders (using DATEDIFF from today)
SELECT 
    order_id, 
    customer_id, 
    order_status, 
    order_approved_ts,
    DATEDIFF(current_date(), order_approved_ts) AS days_since_approved
FROM silver_orders
WHERE order_approved_ts IS NOT NULL
AND order_approved_ts > DATE_SUB(current_date(), 2815)
ORDER BY order_approved_ts DESC
--ORDER BY days_since_approved ASC
LIMIT 10;

-- COMMAND ----------

-- EX 2: Orders missing delivery dates
SELECT order_status, COUNT(*) AS noisnull
FROM silver_orders
WHERE order_delivered_customer_ts IS NULL
GROUP BY order_status
ORDER BY noisnull DESC
--LIMIT 1000;

-- COMMAND ----------

-- EX 3: Orders in a given state (join customers) - SP
SELECT o.order_id, c.customer_state, o.order_purchase_ts
FROM silver_orders o
JOIN silver_customers c
  ON o.customer_id = c.customer_id
WHERE c.customer_state = 'SP'
ORDER BY o.order_purchase_ts DESC
LIMIT 10;

-- COMMAND ----------

-- EX 4: Most expensive order items (price)
SELECT order_id, product_id, price
FROM silver_order_items
ORDER BY price DESC
LIMIT 10;

-- COMMAND ----------

-- EX 5: Join chain (Orders → Customers → Items → Products), sample 20 rows
SELECT
  o.order_id,
  c.customer_state,
  oi.product_id,
  p.product_category_name,
  oi.price,
  oi.freight_value
FROM silver_orders o
JOIN silver_customers c
  ON o.customer_id = c.customer_id
JOIN silver_order_items oi
  ON o.order_id = oi.order_id
LEFT JOIN silver_products p
  ON oi.product_id = p.product_id
LIMIT 20;

-- COMMAND ----------

-- KPI Prep: revenue per order view
CREATE OR REPLACE VIEW silver_order_revenue AS
SELECT
  oi.order_id,
  SUM(oi.price + oi.freight_value) AS order_revenue
FROM silver_order_items oi
GROUP BY oi.order_id;

-- COMMAND ----------

SELECT * FROM silver_order_revenue

-- COMMAND ----------

-- EX 6: Revenue by month
SELECT
  date_trunc('month', o.order_purchase_ts) AS month,
  SUM(CAST(r.order_revenue AS DECIMAL(10,2))) AS revenue
  -- SUM(r.order_revenue) AS revenue
FROM silver_orders o
JOIN silver_order_revenue r
  ON o.order_id = r.order_id
GROUP BY month
ORDER BY month;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC DATE_TRUNC truncates a timestamp down to the specified precision — in this case, 'month'. It effectively "floors/consolidates" every date to the first day of its month.
-- MAGIC \
-- MAGIC All orders in March 2018 — regardless of day/hour — get collapsed to 2018-03-01. This makes them groupable by month, so SUM(r.order_revenue) aggregates all revenue within each calendar month.
-- MAGIC \
-- MAGIC Without DATE_TRUNC, i'd one row per unique timestamp (i.e thousands of rows!). But With DATE_TRUNC, I get one row per month — which can answer exactly what stakeholders need to see revenue trends over time (Year / Quarter / Month / Week / Day). to change the reporting granularity.

-- COMMAND ----------

-- EX 7: Top 10 categories by revenue
SELECT
  COALESCE(p.product_category_name, 'unknown') AS category,
SUM(CAST(oi.price + oi.freight_value AS DECIMAL(10,2))) AS revenue
  -- SUM(oi.price + oi.freight_value) AS revenue
FROM silver_order_items oi
LEFT JOIN silver_products p
  ON oi.product_id = p.product_id
GROUP BY category
ORDER BY revenue DESC
LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC COALESCE(p.product_category_name, 'unknown') AS category
-- MAGIC \
-- MAGIC "Give me the product category name. If it's NULL, Then give me '**unknown**' instead."
-- MAGIC \
-- MAGIC NULLs appear here because of the LEFT JOIN — if an order item's product_id doesn't match any row in silver_products, the joined columns come back as NULL. 
-- MAGIC \
-- MAGIC Without COALESCE, those rows would show a blank category, making my revenue report confusing/misleading to read.

-- COMMAND ----------

-- EX 8: Payment mix
SELECT payment_type, COUNT(*) AS payments, SUM(payment_value) AS total_value
FROM silver_payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- COMMAND ----------

-- MINI Q1: Top 5 products by revenue
SELECT
  oi.product_id,
  COALESCE(p.product_category_name,'unknown') AS category,
  SUM(CAST(oi.price + oi.freight_value AS DECIMAL(10,2))) AS revenue
  -- SUM(oi.price + oi.freight_value) AS revenue
FROM silver_order_items oi
LEFT JOIN silver_products p
  ON oi.product_id = p.product_id
GROUP BY 1,2
ORDER BY revenue DESC
LIMIT 100;

-- COMMAND ----------

-- MINI Q2: Revenue by customer state (top 10)
SELECT
  c.customer_state,
  SUM(CAST(r.order_revenue AS DECIMAL(10,2))) AS revenue
  -- SUM(r.order_revenue) AS revenue
FROM silver_orders o
JOIN silver_customers c
  ON o.customer_id = c.customer_id
JOIN silver_order_revenue r
  ON o.order_id = r.order_id
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;

-- COMMAND ----------

-- MINI Q3: Delivered order rate
SELECT
  ROUND(AVG(CASE WHEN order_delivered_customer_ts IS NOT NULL THEN 1.0 ELSE 0.0 END), 2) AS pct_delivered
  -- ROUND(AVG(CASE WHEN order_delivered_customer_ts IS NOT NULL THEN 1.0 ELSE 0.0 END), 4) AS pct_delivered
FROM silver_orders;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC rounds a decimal number to a specified number of decimal places — here, 2[4] decimal places
-- MAGIC \
-- MAGIC The Steps from the inside out is as follows:
-- MAGIC
-- MAGIC 1. CASE — assigns 1.0 to delivered orders, 0.0 to undelivered ones
-- MAGIC 2. AVG(...) — averages those 1s and 0s, this produces a decimal like 0.966877... (i.e., 96.69% delivered!)
-- MAGIC 3. finally, ROUND(..., 4) — trims that to exactly 4 decimal places → 0.9669
-- MAGIC 4. Without ROUND, the AVG would return something Crazy like 0.96687748... (15+ decimal places) — noisy to digest and hard to read. So, by Rounding to 4 places gives me a cleaner percentage (multiply by 100 → 96.69%) that is presentation-ready for stakeholders down the pipeline.

-- COMMAND ----------

-- GOLD: revenue by month (view)
CREATE OR REPLACE VIEW gold_revenue_by_month AS
SELECT date_trunc('month', o.order_purchase_ts) AS month, SUM(r.order_revenue) AS revenue
FROM silver_orders o
JOIN silver_order_revenue r
  ON o.order_id = r.order_id
GROUP BY 1;

-- COMMAND ----------

-- GOLD: revenue by category (view)
CREATE OR REPLACE VIEW gold_revenue_by_category AS
SELECT COALESCE(p.product_category_name,'unknown') AS category, SUM(oi.price + oi.freight_value) AS revenue
FROM silver_order_items oi
LEFT JOIN silver_products p
  ON oi.product_id = p.product_id
GROUP BY category;

-- COMMAND ----------

-- GOLD: payment mix (view)
CREATE OR REPLACE VIEW gold_payment_mix AS
SELECT payment_type, COUNT(*) AS payments, SUM(payment_value) AS total_value
FROM silver_payments
GROUP BY payment_type;

-- COMMAND ----------

-- Quick Check: orders window
SELECT MIN(order_purchase_ts) AS first_order, MAX(order_purchase_ts) AS last_order
FROM silver_orders;

-- COMMAND ----------

-- Quick Check: entity counts
SELECT
  (SELECT COUNT(DISTINCT customer_id) FROM silver_customers) AS customers,
  (SELECT COUNT(DISTINCT order_id)   FROM silver_orders)    AS orders,
  (SELECT COUNT(*)                    FROM silver_order_items) AS order_items;

-- COMMAND ----------

-- Quick Check: AOV
SELECT ROUND(AVG(order_revenue),2) AS aov
FROM silver_order_revenue;

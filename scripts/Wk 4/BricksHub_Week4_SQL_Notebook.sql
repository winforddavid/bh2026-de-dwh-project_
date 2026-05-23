-- Databricks notebook source
-- Week 4 – Advanced SQL for Real Business Scenarios (Continuation from Week 3)
-- Dialect: Databricks SQL / Spark SQL
-- Note: This workbook assumes your Week 3 catalog/schema are already active.
-- If needed, run the following in a SQL cell before proceeding:
--   USE CATALOG workspace; USE SCHEMA bricks_hub_olist;

-- COMMAND ----------

USE CATALOG workspace;

-- COMMAND ----------

USE SCHEMA bricks_hub_olist

-- COMMAND ----------

-- Day 22: Window Functions — Ranking, Rolling, Running Totals
-- 22.1 Global rank: Top customers by total revenue (one row per customer)
SELECT
  o.customer_id,
  SUM(r.order_revenue)              AS total_revenue,
  ROW_NUMBER() OVER (ORDER BY SUM(r.order_revenue) DESC) AS rn
FROM silver_orders o
JOIN silver_order_revenue r ON o.order_id = r.order_id
GROUP BY o.customer_id;

-- COMMAND ----------

-- 22.2 Rolling 3-month revenue (date_trunc to month + window frame)
WITH monthly AS (
  SELECT
    date_trunc('month', o.order_purchase_ts) AS month,
    SUM(r.order_revenue)                     AS revenue
  FROM silver_orders o
  JOIN silver_order_revenue r ON o.order_id = r.order_id
  GROUP BY month
)
SELECT
  month,
  SUM(revenue) OVER (
    ORDER BY month
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS revenue_roll_3mo
FROM monthly
ORDER BY month;

-- COMMAND ----------

-- 22.3 Running YTD revenue (unbounded → current row frame)
WITH monthly AS (
  SELECT
    date_trunc('month', o.order_purchase_ts) AS month,
    SUM(r.order_revenue)                     AS monthly_rev
  FROM silver_orders o
  JOIN silver_order_revenue r ON o.order_id = r.order_id
  GROUP BY month
)
SELECT
  month,
  SUM(monthly_rev) OVER (
    ORDER BY month
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS ytd_revenue
FROM monthly
ORDER BY month;

-- COMMAND ----------

-- Day 23: Subqueries & CTEs — Cleaner SQL Thinking
-- 23.1 Customers whose total spend > overall average order revenue
SELECT
  o.customer_id,
  SUM(r.order_revenue) AS total_revenue
FROM silver_orders o
JOIN silver_order_revenue r ON o.order_id = r.order_id
GROUP BY o.customer_id
HAVING SUM(r.order_revenue) > (SELECT AVG(order_revenue) FROM silver_order_revenue);

-- COMMAND ----------

-- 23.2 Consecutive-month retention (customer ordered in month M and M+1)
WITH monthly AS (
  SELECT DISTINCT
    customer_id,
    date_trunc('month', order_purchase_ts) AS month
  FROM silver_orders
)
SELECT DISTINCT m1.customer_id
FROM monthly m1
JOIN monthly m2
  ON m2.customer_id = m1.customer_id
 AND m2.month = add_months(m1.month, 1);

-- COMMAND ----------

-- Day 24: CASE Statements — Business Rules
-- 24.1 Delivery SLA (On-time vs Late)
SELECT
  order_id,
  CASE
    WHEN order_delivered_customer_ts IS NULL THEN 'Pending'
    WHEN order_delivered_customer_ts <= order_estimated_delivery_ts THEN 'On-time'
    ELSE 'Late'
  END AS delivery_status
FROM silver_orders;

-- COMMAND ----------

-- 24.2 Payment buckets
SELECT
  order_id,
  CASE
    WHEN COALESCE(payment_value, 0) = 0 THEN 'Free'
    WHEN COALESCE(payment_value, 0) < 50 THEN 'Low'
    ELSE 'High'
  END AS payment_bucket
FROM silver_payments;

-- COMMAND ----------

-- Day 25: Data Cleaning — NULLs & Duplicates
-- 25.1 Replace NULL payments with 0 (ANSI)
SELECT
  order_id,
  COALESCE(payment_value, 0.0) AS safe_payment
FROM silver_payments;

-- COMMAND ----------

-- 25.2 Duplicate order IDs (should be 1 per order in silver_orders)
SELECT
  order_id,
  COUNT(*) AS cnt
FROM silver_orders
GROUP BY order_id
HAVING cnt > 1;

-- COMMAND ----------

-- 25.3 Invalid timeline QA: delivered before approved (should be zero rows)
SELECT
  COUNT(*) AS bad_rows
FROM silver_orders
WHERE order_delivered_customer_ts IS NOT NULL
  AND order_approved_ts IS NOT NULL
  AND order_delivered_customer_ts < order_approved_ts;

-- COMMAND ----------

-- Day 26: Joins at Scale — Complex Queries
-- 26.1 Orders with NO payments (anti-join via LEFT JOIN + IS NULL)
SELECT o.order_id
FROM silver_orders o
LEFT JOIN silver_payments p
  ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- COMMAND ----------

-- 26.2 Orders that DO have items (semi-join via EXISTS)
SELECT o.order_id
FROM silver_orders o
WHERE EXISTS (
  SELECT order_id FROM silver_order_items i
  WHERE i.order_id = o.order_id
);

-- COMMAND ----------

-- 26.3 Seller revenue by customer_state (orders + items + customers)
SELECT
  c.customer_state,
  SUM(i.price + i.freight_value) AS revenue
FROM silver_orders o
JOIN silver_order_items i ON o.order_id = i.order_id
JOIN silver_customers   c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- COMMAND ----------

-- Day 27: Mini Challenge — Customer Retention
-- 27.1 First-order month per customer (cohort assignment)
WITH first_order AS (
  SELECT
    customer_id,
    MIN(date_trunc('month', order_purchase_ts)) AS first_month
  FROM silver_orders
  GROUP BY customer_id
)
SELECT * FROM first_order;

-- COMMAND ----------

-- 27.2 Customers retained (made an order after their first month)
WITH first_order AS (
  SELECT
    customer_id,
    MIN(date_trunc('month', order_purchase_ts)) AS first_month
  FROM silver_orders
  GROUP BY customer_id
)
SELECT COUNT(DISTINCT o.customer_id) AS retained_customers
FROM first_order f
JOIN silver_orders o
  ON f.customer_id = o.customer_id
WHERE date_trunc('month', o.order_purchase_ts) > f.first_month;

-- COMMAND ----------

-- 27.3 Repeat rate (share of customers with >1 orders)
WITH order_counts AS (
  SELECT customer_id, COUNT(*) AS orders_cnt
  FROM silver_orders
  GROUP BY customer_id
)
SELECT
  SUM(CASE WHEN orders_cnt > 1 THEN 1 ELSE 0 END) / COUNT(*) AS repeat_rate
FROM order_counts;

-- COMMAND ----------

-- Day 28: Recap & Leaderboard — Advanced SQL Wins
-- 28.1 Month-over-month revenue delta using LAG
WITH monthly AS (
  SELECT
    date_trunc('month', o.order_purchase_ts) AS month,
    SUM(r.order_revenue) AS revenue
  FROM silver_orders o
  JOIN silver_order_revenue r ON o.order_id = r.order_id
  GROUP BY 1
)
SELECT
  month,
  revenue,
  revenue - LAG(revenue) OVER (ORDER BY month) AS mom_change
FROM monthly
ORDER BY month;

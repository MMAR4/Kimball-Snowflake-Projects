CREATE  WAREHOUSE scd6_wh
WAREHOUSE_SIZE = "xsmall"
AUTO_SUSPEND = 60;
USE WAREHOUSE scd6_wh;

-- TASK 1 — Create Database and Schema Context
CREATE DATABASE RETAIL_DW;
USE DATABASE RETAIL_DW;

CREATE SCHEMA SALES_ANALYTICS;
USE SCHEMA SALES_ANALYTICS;

SELECT CURRENT_DATABASE(), CURRENT_SCHEMA();

CREATE FILE FORMAT csv_format
type = 'csv'
field_delimiter = ','
skip_header = 2
skip_blank_lines = TRUE;

CREATE STAGE scd_stage
file_format = csv_format;


-- TASK 2 — Create Store Conformed Dimension Table (`DIM_STORE`)
CREATE OR REPLACE  TABLE dim_store(
store_key INT PRIMARY KEY AUTOINCREMENT,
store_id INT NOT NULL,
store_name VARCHAR,
city VARCHAR,
state VARCHAR,
store_manager VARCHAR
);

-- TASK 3 — Create Product Dimension Table (`DIM_PRODUCT`)
CREATE OR REPLACE TABLE dim_product(
product_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
product_id INT NOT NULL,
product_name VARCHAR,
category VARCHAR,
unit_price NUMBER(10,2)
);

CREATE OR REPLACE TABLE customer_initial(
customer_id INT PRIMARY KEY,
customer_name VARCHAR,
city VARCHAR,
state VARCHAR,
membership VARCHAR,
segment VARCHAR
);

CREATE OR REPLACE  TABLE customer_updates(
customer_id INT PRIMARY KEY,
customer_name VARCHAR,
city VARCHAR,
state VARCHAR,
membership VARCHAR,
segment VARCHAR,
effective_date DATE
);

-- TASK 4 — Create Hybrid Customer Dimension Table (`DIM_CUSTOMER_HYBRID`)
CREATE OR REPLACE TABLE dim_customers_hybrid(
customer_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
customer_id INT NOT NULL,
customer_name VARCHAR,

city VARCHAR,
previous_city VARCHAR,

state VARCHAR,

current_membership VARCHAR,
previous_membership VARCHAR,
historical_membership VARCHAR,

segment VARCHAR,
effective_date DATE,
expiry_date DATE,
is_current BOOLEAN

);



-- TASK 5 — Populate Initial Store and Product Dimension Data
COPY INTO dim_store (store_id,store_name,city,state,store_manager)
FROM @scd_stage
FILES = ('stores.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

COPY INTO dim_product(product_id,product_name,category,unit_price)
FROM @scd_stage
FILES = ('products.csv')
file_format = (format_name = 'csv_format');

TRUNCATE dim_product;
SELECT * FROM dim_product;

COPY INTO customer_initial
FROM @scd_stage/customers_ini.csv;

COPY INTO customer_updates 
FROM @scd_stage/customers_upd.csv;

-- TASK 6 — Populate Initial Customer Dimension Data

INSERT INTO dim_customers_hybrid 
(
customer_id,customer_name,
city,previous_city,
state,
current_membership,previous_membership,historical_membership,
segment,
effective_date,expiry_date,is_current
)
SELECT customer_id,customer_name,city,NULL,state,membership,NULL,membership,segment,'2026-01-01','9999-12-31',TRUE
FROM customer_initial;
SELECT * FROM dim_customers_hybrid;


-- TASK 7 — Create Sales Transaction Fact Table (`FACT_SALES`)
CREATE OR REPLACE TABLE fact_sales(
sales_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
transaction_id VARCHAR NOT NULL,
transaction_date DATE,
customer_key INT NOT NULL,
store_key NUMBER NOT NULL,
product_key NUMBER NOT NULL,
quantity NUMBER,
unit_price NUMBER(10,2),
total_amount NUMBER(10,2),

FOREIGN KEY (customer_key) REFERENCES dim_customers_hybrid(customer_key),
FOREIGN KEY (store_key) REFERENCES dim_store(store_key),
FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
);

-- TASK 8 — Insert Q1 2026 Sales Fact Transactions
-- 1. Transaction `TXN-1001` on `'2026-02-15'`: Customer 101 purchases 1 unit of Product 501 at Store 201.
INSERT INTO fact_sales (transaction_id,transaction_date,customer_key,store_key, product_key,quantity, unit_price,total_amount)
SELECT 'TXN-1001','2026-02-15',c.customer_key,s.store_key,p.product_key,1,p.unit_price,p.unit_price * 1
FROM dim_customers_hybrid c
JOIN dim_store s ON store_id = 201
JOIN dim_product p ON product_id = 501
WHERE customer_id = 101 
    AND is_current = TRUE;

SELECT * FROM fact_sales;

-- 2. Transaction `TXN-1002` on `'2026-03-10'`: Customer 103 purchases 2 units of Product 502 at Store 203.
INSERT INTO fact_sales (transaction_id,transaction_date,customer_key,store_key, product_key,quantity, unit_price,total_amount)
SELECT 'TXN-1002','2026-03-10',c.customer_key,s.store_key,p.product_key,2,p.unit_price,p.unit_price * 2
FROM dim_customers_hybrid c
JOIN dim_store s ON store_id = 203
JOIN dim_product p ON product_id = 502
WHERE customer_id = 103 
    AND is_current = TRUE;


-- TASK 9 — Apply Store Manager Update (SCD Type 1 Overwrite)
UPDATE dim_store 
SET store_manager = 'Suresh Menon'
WHERE store_id = 201;


-- TASK 10 — Execute Multi-Attribute Customer Updates

-- Step 1 Expire active records for Customers 101, 103, and 104 by updating `EXPIRY_DATE` to the day before their `effective_date` and setting `IS_CURRENT = FALSE`.

SELECT * FROM customer_updates;
SELECT * FROM dim_customers_hybrid;

UPDATE dim_customers_hybrid o
SET is_current = FALSE,
    expiry_date = u.effective_date - 1
FROM  customer_updates u 

WHERE o.customer_id = u.customer_id 
    AND o.is_current = TRUE
    AND o.customer_id IN (101,103,104);

SELECT * FROM dim_customers_hybrid ORDER BY customer_id;

-- Step 2: Insert new active row versions for updated customers with `IS_CURRENT = TRUE` and `EXPIRY_DATE = '9999-12-31'`. Preserve their old city in `PREVIOUS_CITY`.

INSERT INTO dim_customers_hybrid 
(customer_id,customer_name,
city,previous_city,
state,
current_membership,previous_membership,historical_membership,
segment,
effective_date,expiry_date,is_current
)
SELECT 
    u.customer_id,u.customer_name,
    u.city, o.city,u.state, u.membership,o.current_membership,u.membership,u.segment,u.effective_date,'9999-12-31',TRUE
FROM customer_updates u
JOIN dim_customers_hybrid o 
ON o.customer_id = u.customer_id
WHERE o.is_current = FALSE;



SELECT * FROM dim_customers_hybrid ORDER BY customer_id,is_current;

-- Step 3: Synchronize `CURRENT_MEMBERSHIP`, `PREVIOUS_MEMBERSHIP`, `CITY`, and `STATE` across **all** historical rows for affected customers so current profile attributes match everywhere.

UPDATE dim_customers_hybrid o
SET
    o.previous_membership = o.current_membership,
    o.current_membership = u.membership,
    o.previous_city = o.city,
    o.city = u.city,
    o.state = u.state

FROM customer_updates u 
WHERE u.customer_id = o.customer_id
    AND o.is_current = FALSE;

SELECT * 
FROM dim_customers_hybrid
ORDER BY customer_id;


-- TASK 11 — Insert Q2 2026 Sales Transaction
INSERT INTO fact_sales (transaction_id ,transaction_date ,customer_key ,store_key ,product_key ,quantity, unit_price ,total_amount)
SELECT 'TXN-2001','2026-04-15',c.customer_key, s.store_key, p.product_key, 1, p.unit_price, p.unit_price * 1
FROM dim_customers_hybrid c 
JOIN dim_store s 
    ON s.store_id = 201
JOIN dim_product p 
    ON p.product_id = 503
WHERE c.customer_id = 101
    AND c.is_current = TRUE;

SELECT * FROM fact_sales;

-- TASK 12 — Display Full Customer Dimension History
SELECT * 
FROM dim_customers_hybrid
ORDER BY customer_id,effective_date;


-- TASK 13 — Point-in-Time Point-of-Sale Analytics Query
SELECT s.transaction_id,s.transaction_date,c.customer_id,c.customer_name,c.city, c.current_membership,c.segment,ds.store_name,p.product_name,s.total_amount
FROM fact_sales s
JOIN dim_customers_hybrid c 
ON s.customer_key = c.customer_key
JOIN dim_product p 
ON s.product_key = p.product_key
JOIN dim_store ds 
ON s.store_key = ds.store_key
WHERE c.customer_id = 101;

-- TASK 14 — Warehouse Record Count and Data Auditing Validation
SELECT 'STORE DIMENSION RECORDS' AS metric, COUNT(*) AS VALUE
FROM dim_store
UNION ALL 
SELECT 'PRODUCT DIMENSION RECORDS', COUNT(*)
FROM dim_product
UNION ALL 
SELECT 'TOTAL CUSTOMER DIMENSION RECORDS', COUNT(*)
FROM dim_customers_hybrid
UNION ALL
SELECT 'CURRENT CUSTOMER RECORDS', COUNT_IF(is_current = TRUE)
FROM dim_customers_hybrid
UNION ALL
SELECT 'HISTORICAL CUSTOMER RECORDS', COUNT_IF(is_current = FALSE)
FROM dim_customers_hybrid
UNION ALL 
SELECT 'FACT SALES TRANSACTIONS', COUNT(*)
FROM fact_sales;


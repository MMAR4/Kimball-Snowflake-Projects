CREATE WAREHOUSE project19_wh
WITH 
AUTO_SUSPEND = 60
WAREHOUSE_SIZE = 'xsmall';
USE WAREHOUSE project19_wh;

CREATE DATABASE project19_db;
USE DATABASE project19_db;

CREATE SCHEMA project19_schema;
USE SCHEMA project19_schema;

CREATE FILE FORMAT csv_format
TYPE = 'csv'
skip_header = 1 
skip_blank_lines = TRUE 
FIELD_DELIMITER = ',';

CREATE STAGE raw_stage
file_format = csv_format;

-- TASK 1: Build Junk Dimension Table

CREATE TABLE DIM_ORDER_INDICATORS (
indicator_sk INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
payment_method STRING,
shipping_option STRING,
gift_wrap_flag STRING
);

INSERT INTO DIM_ORDER_INDICATORS(payment_method, shipping_option,gift_wrap_flag)
SELECT DISTINCT $7,$8,$9 
FROM @raw_stage/raw_orders.csv;

SELECT * FROM dim_order_indicators;


-- TASK 2: Build Transaction Fact Table with Degenerate Dimension
CREATE OR REPLACE TABLE FACT_SALES_TRANSACTIONS (
order_id STRING,
indicator_sk INT REFERENCES dim_order_indicators(indicator_sk),
user_id STRING,
store_id STRING,
amount NUMBER(10,2),
tax NUMBER(10,2)
);

SELECT * FROM dim_order_indicators;
INSERT INTO fact_sales_transactions (order_id, indicator_sk, user_id,store_id, amount, tax)
SELECT r.$1 ,d.indicator_sk ,r.$3,r.$4, r.$5, r.$6
FROM @raw_stage/raw_orders.csv r
JOIN dim_order_indicators d 
    ON d.payment_method = r.$7 AND
     d.shipping_option = r.$8 AND 
     d.gift_wrap_flag = r.$9;

SELECT ORDER_ID, INDICATOR_SK, AMOUNT
FROM fact_sales_transactions;


-- TASK 3: Periodic Snapshot Rollup & Semi-Additive Metrics
CREATE TABLE FACT_INVENTORY_SNAPSHOT(
snapshot_date DATE,
store_id STRING,
total_units_held INT,
total_inventory_val NUMBER(10,2)
);

INSERT INTO fact_inventory_snapshot
SELECT $1, $2,SUM($4),SUM($4*$5) 
FROM @raw_stage/raw_inventory.csv
GROUP BY $1,$2;

SELECT * FROM fact_inventory_snapshot;

-- TASK 4: Accumulating Milestone Lag Duration Calculations
CREATE OR REPLACE TABLE FACT_ORDER_FULFILLMENT(
order_id STRING,
order_date DATE,
pick_date DATE,
ship_date DATE,
delivery_date DATE,
pick_lag_days INT,
ship_lag_days INT,
delivery_lag_days INT,
total_fulfillment_days INT 
);

INSERT INTO FACT_ORDER_FULFILLMENT 
WITH cte AS (
SELECT  $1 c1,
        $2,
        NULLIF($3,'NULL'),
        NULLIF($4,'NULL'),
        NULLIF($5,'NULL'),
        DATEDIFF('day',$2,$3) c2,
        DATEDIFF('day',$3,NULLIF($4,'NULL')) c3,
        DATEDIFF('day',NULLIF($4,'NULL'),NULLIF($5,'NULL')) c4
FROM @raw_stage/raw_fulfillment.csv
)
SELECT *, c2+c3+c4 
FROM cte;

SELECT *
FROM FACT_ORDER_FULFILLMENT 
WHERE DELIVERY_LAG_DAYS IS NOT NULL ;
-- TASK 5: Incomplete Lifecycle Status Auditing
-- - Query `FACT_ORDER_FULFILLMENT` to identify pending orders (`DELIVERY_DATE IS NULL`) and output current milestone status.
SELECT  order_id,order_date, 
        CASE 
            WHEN pick_date IS NULL 
                THEN  'ORDERED_NOT_PICKED'
            WHEN ship_date IS NULL 
                THEN 'PICKED_NOT_SHIPPED'
            WHEN delivery_date IS NULL 
                THEN 'SHIPPED_NOT_DELIVERED'
        END AS current_status
        
FROM FACT_ORDER_FULFILLMENT
WHERE DELIVERY_DATE IS NULL;


-- TASK 6: Aggregate Revenue Summary by Junk Dimension Indicators
-- - Query revenue (`AMOUNT`) grouped by `PAYMENT_METHOD` using `DIM_ORDER_INDICATORS` and `FACT_SALES_TRANSACTIONS`.
SELECT payment_method, COUNT(order_id) AS TOTAL_ORDERS, SUM(amount) AS TOTAL_REVENUE
FROM dim_order_indicators d
JOIN fact_sales_transactions f
    ON d.indicator_sk = f.indicator_sk
GROUP BY payment_method;

SELECT * FROM dim_order_indicators;



CREATE OR REPLACE WAREHOUSE scd36_wh
WITH
AUTO_SUSPEND = 60
WAREHOUSE_SIZE = 'xsmall';
USE WAREHOUSE scd36_wh;


-- TASK 1 — Create Database and Schema
CREATE DATABASE scd36_db;
USE DATABASE scd36_db;

CREATE SCHEMA scd_schema;
USE SCHEMA scd_schema;

CREATE FILE FORMAT csv_format 
type = 'csv'
field_delimiter = ','
skip_header =1
skip_blank_lines = TRUE ;

CREATE OR REPLACE STAGE scd_stage
file_format = csv_format;


-- TASK 2 — Create Type 3 Dimension
CREATE OR REPLACE TABLE dim_customers(
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    membership VARCHAR,
    segment VARCHAR
);


CREATE OR REPLACE TABLE dim_customers_updates(
customer_id INT PRIMARY KEY ,
customer_name VARCHAR,
city VARCHAR,
state VARCHAR,
membership VARCHAR,
segment VARCHAR,
effective_date DATE
);

COPY INTO dim_customers
FROM @scd_stage/customers_ini.csv;

COPY INTO dim_customers_updates
FROM @scd_stage/customers_upd.csv;

CREATE OR REPLACE TABLE dim_customers_type3(
    customer_key INT PRIMARY KEY AUTOINCREMENT,
    customer_id INT UNIQUE NOT NULL, 
    customer_name VARCHAR ,
    city VARCHAR,
    state VARCHAR,
    current_membership VARCHAR,
    previous_membership VARCHAR DEFAULT NULL,
    segment VARCHAR
);

INSERT INTO dim_customers_type3 (customer_id,customer_name,city,state,current_membership,segment)
SELECT customer_id,customer_name,city,state,membership,segment
FROM dim_customers;

-- TASK 4 — Display Initial Type 3 Data
SELECT * FROM dim_customers_type3;


-- TASK 5 — Apply SCD Type 3 Changes
-- TASK 6 — Update Type 3 Dimension

MERGE INTO dim_customers_type3 o
USING dim_customers_updates u 
    ON o.customer_id = u.customer_id

    WHEN MATCHED THEN
    UPDATE SET 
        o.previous_membership = o.current_membership,
        o.current_membership = u.membership,
        o.city = u.city,
        o.state = u.state,
        o.segment = u.segment;


-- TASK 7 — Type 3 Final Report
SELECT * 
FROM dim_customers_type3
ORDER BY customer_id;


-- TASK 8 — Demonstrate Type 3
SELECT * 
FROM dim_customers_type3
WHERE customer_id = 101;


-- TASK 9 — Create Type 6 Dimension
CREATE OR REPLACE TABLE dim_customers_type6(
    customer_key INT PRIMARY KEY AUTOINCREMENT ,
    customer_id INT,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    current_membership VARCHAR,
    previous_membership VARCHAR,
    historical_membership VARCHAR,
    segment VARCHAR,
    effective_date DATE,
    expiry_date DATE,
    is_current BOOLEAN
);


-- TASK 10 — Load Initial Type 6 Records
INSERT INTO dim_customers_type6 (customer_id,customer_name,city,state,current_membership,previous_membership,historical_membership,segment,effective_date,expiry_date,is_current)
SELECT customer_id,customer_name,city,state,membership,null,membership,segment,'2026-01-01','9999-12-31',TRUE
FROM dim_customers;


-- TASK 11 — Apply Type 6 Change for Customer 101
UPDATE dim_customers_type6
SET 
    expiry_date = '2026-03-31',
    is_current = FALSE
WHERE customer_id = 101
    AND is_current = TRUE;

INSERT INTO dim_customers_type6 (customer_id,customer_name,city,state,current_membership,previous_membership,historical_membership,segment,effective_date,expiry_date,is_current)
SELECT u.customer_id,u.customer_name,u.city,u.state,u.membership,o.current_membership,o.historical_membership,u.segment,u.effective_date,'9999-12-31',TRUE
FROM dim_customers_type6 o 
JOIN dim_customers_updates u 
    ON o.customer_id = u.customer_id
WHERE o.customer_id = 101
    AND o.is_current = FALSE
    AND expiry_date = '2026-03-31';

SELECT * FROM dim_customers_type6;
SELECT * FROM dim_customers_updates;

-- TASK 12 — Apply Remaining Changes
UPDATE dim_customers_type6 o
SET 
    o.expiry_date = DATEADD(DAY,-1,u.effective_date),
    o.is_current = FALSE 
FROM dim_customers_updates u  
WHERE o.customer_id = u.customer_id
    AND is_current = TRUE 
    AND o.current_membership <> u.membership;
    
INSERT INTO dim_customers_type6 
(customer_id,customer_name,city,state,current_membership,previous_membership,historical_membership,segment,effective_date,expiry_date,is_current)
SELECT u.customer_id,u.customer_name,u.city, u.state, u.membership, o.current_membership, o.historical_membership,u.segment,u.effective_date,'9999-12-31',TRUE
FROM dim_customers_updates u 
JOIN dim_customers_type6 o 
ON u.customer_id = o.customer_id
WHERE o.is_current = FALSE
    AND o.expiry_date = DATEADD(DAY, -1,u.effective_date)
    AND u.customer_id IN (103,104);

-- TASK 13 — Display Complete Type 6 History
SELECT * 
FROM dim_customers_type6
ORDER BY customer_id;

-- TASK 14 — Current Customer Report
SELECT * 
FROM dim_customers_type6 
WHERE is_current = TRUE
ORDER BY customer_id;

-- TASK 15 — Point-in-Time Historical Query
SELECT customer_id,customer_name,current_membership,effective_date,expiry_date
FROM dim_customers_type6
WHERE customer_id = 101 AND '2026-03-15' BETWEEN effective_date AND expiry_date; 


-- TASK 16 — Type 3 vs Type 6
-- ---------
-- SCD TYPE 3
-- --------------------------------
-- Current Value       YES
-- Previous Value      YES
-- Historical Rows     NO
-- Effective Date      NO
-- Expiry Date         NO
-- IS_CURRENT          NO


-- SCD TYPE 6
-- --------------------------------
-- Current Value       YES
-- Previous Value      YES
-- Historical Rows     YES
-- Effective Date      YES
-- Expiry Date         YES
-- IS_CURRENT          YES


-- TASK 17 — Record Count Validation

-- SCD TYPE 3 RECORD COUNT
SELECT COUNT(*) AS scd_type3_record_count
FROM dim_customers_type3;


-- SCD TYPE 6 RECORD COUNT
SELECT COUNT(*) AS scd_type6_record_count
FROM dim_customers_type6;


-- SCD TYPE 6 CURRENT RECORD COUNT
SELECT COUNT(*) AS scd_type6_current_record_count
FROM dim_customers_type6
WHERE is_current = TRUE;


-- SCD TYPE 6 HISTORICAL RECORD COUNT
SELECT COUNT(*) AS scd_type6_historical_record_count
FROM dim_customers_type6
WHERE is_current = FALSE;

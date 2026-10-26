CREATE WAREHOUSE scd1236_wh
WITH 
AUTO_SUSPEND = 60
WAREHOUSE_SIZE = 'xsmall';

USE WAREHOUSE scd1236_wh;


-- TASK 1 — Create Database and Schema
CREATE DATABASE scd1236_db;
USE DATABASE scd1236_db;

CREATE SCHEMA scd_schema;
USE SCHEMA scd_schema;

CREATE FILE FORMAT csv_format 
type = 'csv'
field_delimiter = ','
skip_header = 1
skip_blank_lines = TRUE;

CREATE OR REPLACE STAGE scd_stage
file_format = csv_format;

CREATE TABLE dim_customers(
customer_id INT PRIMARY KEY,
customer_name VARCHAR,
city VARCHAR,
state VARCHAR,
membership VARCHAR,
segment VARCHAR
);

CREATE TABLE dim_customers_updates(
customer_id INT PRIMARY KEY,
customer_name VARCHAR,
city VARCHAR,
state VARCHAR,
membership VARCHAR,
segment VARCHAR,
effective_date DATE
);

COPY INTO dim_customers 
FROM @scd_stage
files = ('customers_ini.csv')
file_format = (format_name = 'csv_format');

COPY INTO dim_customers_updates
FROM @scd_stage/customers_upd.csv;

SELECT * FROM dim_customers_updates;


-- TASK 2 — Create Hybrid Dimension Table
CREATE TABLE dim_customers_types(
customer_key INT PRIMARY KEY AUTOINCREMENT, 
customer_id INT NOT NULL ,
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


-- TASK 3 — Load Initial Dimension Data
INSERT INTO dim_customers_types (customer_id,customer_name,city,previous_city,state,current_membership,previous_membership,historical_membership,segment,effective_date,expiry_date,is_current)
SELECT  customer_id,customer_name,city,NULL,state,membership,NULL,membership,segment,'2026-01-01','9999-12-31',TRUE
FROM dim_customers;


-- TASK 4 — Display Initial Dimension State
SELECT * 
FROM dim_customers_types;



-- TASK 5 — Apply Hybrid Updates for Customers 101, 103, and 104
MERGE INTO dim_customers_types o
USING dim_customers_updates u
    ON o.customer_id = u.customer_id AND is_current = TRUE

    WHEN MATCHED AND (o.state <> u.state OR o.city <> u.city OR o.current_membership <> u.membership) THEN 
    UPDATE SET
    o.state = u.state,

    o.previous_city = o.city,
    o.city = u.city,

    o.previous_membership = o.current_membership,
    o.current_membership = u.membership,

    o.expiry_date = DATEADD(DAY, -1 ,u.effective_date),
    o.is_current = FALSE;
    
    
INSERT INTO dim_customers_types (customer_id,customer_name,city,previous_city,state,current_membership,previous_membership,historical_membership,segment,effective_date,expiry_date,is_current)

SELECT 
o.customer_id,o.customer_name,o.city,o.previous_city,o.state,u.membership,o.previous_membership,u.membership,u.segment,u.effective_date, '9999-12-31',TRUE  

FROM dim_customers_updates u 
JOIN dim_customers_types o
ON u.customer_id = o.customer_id
AND is_current = FALSE;

-- TASK 6 — Display Complete Dimension History
SELECT * 
FROM dim_customers_types
ORDER BY customer_id;


-- TASK 7 — Display Active Customer Report
SELECT * 
FROM dim_customers_types 
WHERE is_current = TRUE
ORDER BY customer_id;

-- TASK 8 — Point-in-Time Historical Query
SELECT CUSTOMER_ID,CUSTOMER_NAME, CITY, HISTORICAL_MEMBERSHIP, SEGMENT, EFFECTIVE_DATE, EXPIRY_DATE
FROM dim_customers_types 
WHERE customer_id = 101 AND '2026-03-15' BETWEEN EFFECTIVE_DATE AND EXPIRY_DATE
ORDER BY customer_id;


-- TASK 9 — Metric Validation and Record Counts
SELECT 'TOTAL RECORD COUNT' AS "metric", COUNT(*) AS value
FROM dim_customers_types

UNION 
SELECT 'CURRENT RECORD COUNT', COUNT(*)
FROM dim_customers_types
WHERE is_current = TRUE

UNION
SELECT 'HISTORICAL RECORD COUNT', COUNT(*)
FROM dim_customers_types
WHERE is_current = FALSE
;


CREATE OR REPLACE WAREHOUSE scd_wh
WITH 
AUTO_SUSPEND = 60
WAREHOUSE_SIZE = 'xsmall';
USE WAREHOUSE scd_wh;

CREATE DATABASE scd_db;
USE DATABASE scd_db;

CREATE SCHEMA scd_schema;
USE SCHEMA scd_schema;

CREATE FILE FORMAT csv_format
TYPE = 'csv'
FIELD_DELIMITER = ','
SKIP_HEADER=1
SKIP_BLANK_LINES = TRUE ;

CREATE STAGE scd_stage
FILE_FORMAT = csv_format;


CREATE TABLE dim_customer(
CUSTOMER_KEY INT PRIMARY KEY AUTOINCREMENT ,
CUSTOMER_ID INT UNIQUE,
CUSTOMER_NAME VARCHAR(20),
CITY VARCHAR(20),
STATE VARCHAR(30),
MEMBERSHIP VARCHAR(20),
SEGMENT VARCHAR(20)
);

COPY INTO dim_customer(customer_id,customer_name,city,state,membership,segment)
FROM @scd_stage/customers_initial.csv;

SELECT * FROM dim_customer;

CREATE STAGE scd_stage_updated
FILE_FORMAT = csv_format;

CREATE TABLE dim_customer_update(
    CUSTOMER_KEY INT PRIMARY KEY AUTOINCREMENT ,
    CUSTOMER_ID INT UNIQUE,
    CUSTOMER_NAME VARCHAR(20),
    CITY VARCHAR(20),
    STATE VARCHAR(30),
    MEMBERSHIP VARCHAR(20),
    SEGMENT VARCHAR(20)
);

COPY INTO dim_customer_update (customer_id,customer_name,city,state,membership,segment)
FROM @scd_stage_updated;

SELECT * FROM dim_customer_update;


-- Task 6 — Identify Changed Customers
SELECT c.customer_id,c.city AS old_city ,u.city AS new_city, c.membership AS old_membership , u.city AS new_memebership
FROM dim_customer c
JOIN dim_customer_update u
    ON c.customer_id = u.customer_id;


-- Task 7 — Identify Attribute Changes
WITH cte AS
(SELECT c.customer_id,
        c.city AS old_city,
        u.city AS new_city,
        c.state AS old_state,
        u.state AS new_state,
        c.membership AS old_m,
        u.membership AS new_m
        
FROM dim_customer c
JOIN dim_customer_update u
    ON c.customer_id = u.customer_id
 
        WHERE c.city <> u.city
           OR c.state <> u.state
           OR c.membership <> u.membership
           OR c.segment <> u.segment
    )       
    
SELECT customer_id,'CITY' AS attribute,old_city,new_city 
FROM cte
UNION ALL 

SELECT customer_id,'STATE' AS attribute,old_state,new_state 
FROM cte
UNION ALL 
SELECT customer_id,'MEMBERSHIP' AS attribute,old_m,new_m
FROM cte

ORDER BY customer_id
;


-- ============================================================
-- TASK 8 : DEMONSTRATE SCD TYPE 1
-- OVERWRITE EXISTING CUSTOMER INFORMATION
-- ============================================================

SELECT * FROM dim_customer;

MERGE INTO dim_customer o 
USING dim_customer_update u
    ON o.customer_id = u.customer_id

    WHEN MATCHED THEN 
        UPDATE SET 
            o.customer_name = u.customer_name,
            o.city = u.city,
            o.state = u.state,
            o.membership = u.membership,
            o.segment = u.segment;


-- TASK 9 : DISPLAY UPDATED DIMENSION
SELECT * 
FROM dim_customer
ORDER BY customer_id;

-- TASK 10 : DEMONSTRATE HISTORICAL DATA LOSS
SELECT * 
FROM dim_customer
WHERE customer_id = 101;

-- TASK 11 : BUSINESS IMPACT ANALYSIS
SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership
FROM dim_customer
WHERE customer_id = 101;

-- Before update:
-- Hyderabad | Telangana | Silver

-- After update:
-- Bengaluru | Karnataka | Gold

-- Historical values:
-- Hyderabad | Telangana | Silver → LOST

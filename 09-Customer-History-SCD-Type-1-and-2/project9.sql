CREATE WAREHOUSE scd2_wh
WITH 
AUTO_SUSPEND = 60
WAREHOUSE_SIZE = "XSMALL";
USE WAREHOUSE scd2_wh;

-- TASK 1 — Create Database and Schema
CREATE DATABASE scd2_db;
USE DATABASE scd2_db;

CREATE SCHEMA scd_schema;
USE SCHEMA scd_schema;

CREATE FILE FORMAT csv_format
type = 'csv'
field_delimiter = ','
skip_header = 1 
skip_blank_lines = TRUE ;

CREATE OR REPLACE STAGE scd2_stage
file_format = csv_format;

-- TASK 2 — Create SCD Type 1 Table
CREATE TABLE customers (
customer_key INT PRIMARY KEY AUTOINCREMENT,
customer_id INT UNIQUE,
customer_name VARCHAR(20),
city VARCHAR(20),
state VARCHAR,
membership VARCHAR,
segment VARCHAR
);

CREATE OR REPLACE TABLE customer_updates(
customer_key INT PRIMARY KEY AUTOINCREMENT,
customer_id INT ,
customer_name VARCHAR(20),
city VARCHAR(20),
state VARCHAR,
membership VARCHAR,
segment VARCHAR,
effective_date DATE
);


LIST @scd2_stage;


-- TASK 3 — Load Initial Type 1 Data
COPY INTO customers(customer_id,customer_name,city,state,membership,segment)
FROM @scd2_stage/customers_initial.csv;

COPY INTO customer_updates (customer_id,customer_name,city,state,membership,segment,effective_date)
FROM @scd2_stage/customer_updates.csv;



-- TASK 4 — Apply SCD Type 1 Updates
MERGE INTO customers o
USING customer_updates u
    ON o.customer_id = u.customer_id

    WHEN MATCHED THEN 
        UPDATE SET 
        o.customer_name = u.customer_name,
        o.city = u.city,
        o.state = u.state,
        o.membership = u.membership,
        o.segment = u.segment;


-- TASK 5 — Display Type 1 Result
SELECT * 
FROM customers
ORDER BY customer_id;


-- TASK 6 — Demonstrate Type 1 History Loss
SELECT * 
FROM customers
WHERE customer_id = 101;


-- TASK 7 — Create SCD Type 2 Table
CREATE OR REPLACE TABLE customers2 (
customer_key INT PRIMARY KEY AUTOINCREMENT,
customer_id INT,
customer_name VARCHAR ,
city VARCHAR,
state VARCHAR,
membership VARCHAR,
segment VARCHAR,
effective_date DATE DEFAULT TO_DATE('2026-01-01'),
EXPIRY_DATE DATE DEFAULT TO_DATE('9999-12-31'),
is_current BOOLEAN DEFAULT TRUE
);


COPY INTO customers2 (customer_id,customer_name,city,state,membership,segment)
FROM @scd2_stage/customers_initial.csv;

SELECT * FROM customers2;


-- TASK 8 — Create Type 2 Table
CREATE OR REPLACE TABLE customers2_updates (
customer_id INT,
customer_name VARCHAR ,
city VARCHAR,
state VARCHAR,
membership VARCHAR,
segment VARCHAR,
effective_date DATE,
EXPIRY_DATE DATE DEFAULT TO_DATE('9999-12-31'),
is_current BOOLEAN DEFAULT TRUE
);

-- TASK 9 — Load Initial Type 2 Records
COPY INTO customers2_updates (customer_id,customer_name,city,state,membership,segment,effective_date)
FROM @scd2_stage/customer_updates.csv;

SELECT * FROM customers2_updates;

-- TASK 10 — Apply Type 2 Changes
MERGE INTO customers2 o
USING customers2_updates u
    ON o.customer_id = u.customer_id AND o.is_current = TRUE

    WHEN MATCHED THEN 
        UPDATE SET
        o.expiry_date = u.effective_date - 1,
        o.is_current = FALSE;

SELECT * 
FROM customers2 
ORDER BY customer_id;

INSERT INTO customers2 (customer_id,customer_name,city,state,membership,segment,effective_date,is_current)
SELECT customer_id,customer_name,city,state,membership,segment,effective_date,is_current
FROM customers2_updates;



-- TASK 11 — Customer 101 Type 2 Change
SELECT * 
FROM customers2
WHERE customer_id =101;


-- TASK 12 — Customer 103 Type 2 Change
SELECT * 
FROM customers2
WHERE customer_id = 103;


-- TASK 13 — Customer 104 Type 2 Change
SELECT * 
FROM customers2
WHERE customer_id = 104;


-- TASK 14 — Display Complete Type 2 History
SELECT * FROM customers2;


-- TASK 15 — Display Current Customer Records
SELECT * 
FROM customers2 
WHERE is_current = TRUE;


-- TASK 16 — Historical Customer Analysis
SELECT * 
FROM customers2 
WHERE customer_id = 101 AND '2026-03-15' BETWEEN effective_date AND expiry_date ;


-- TASK 17 — Compare Type 1 vs Type 2
SELECT * 
FROM customers;

SELECT * 
FROM customers2;

-- | Feature             | Type 1 | Type 2 |
-- | ------------------- | ------ | ------ |
-- | Old value preserved | ❌ No   | ✅ Yes  |
-- | New row created     | ❌ No   | ✅ Yes  |
-- | Historical analysis | ❌ No   | ✅ Yes  |
-- | Effective date      | ❌ No   | ✅ Yes  |
-- | Expiry date         | ❌ No   | ✅ Yes  |
-- | IS_CURRENT          | ❌ No   | ✅ Yes  |


-- TASK 18 — Final Validation

SELECT COUNT(*) AS total_type1
FROM customers;

SELECT COUNT(*) AS total_type2
FROM customers2;

SELECT COUNT(*) AS current_type2
FROM customers2
WHERE is_current = TRUE;

SELECT COUNT(*) AS historical_type2
FROM customers2
WHERE is_current = FALSE;

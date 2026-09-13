CREATE WAREHOUSE project15
WITH 
WAREHOUSE_SIZE = "xsmall"
AUTO_SUSPEND = 60;

USE WAREHOUSE project15;

CREATE DATABASE project15_db;
USE DATABASE project15_db;

CREATE SCHEMA fleet_core;
USE SCHEMA fleet_core;

CREATE FILE FORMAT text_format
type = 'csv'
field_delimiter = NONE
record_delimiter = '\n'
skip_header = 0; // record_delimiter default value is '\n' and skip_header default value is 0, written just for clarification 

CREATE OR REPLACE STAGE project15_stage
FILE_FORMAT = text_format;

CREATE TABLE raw_iot_landing(
raw_record STRING,
timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

COPY INTO raw_iot_landing(raw_record)
FROM @project15_stage;

SELECT * FROM raw_iot_landing;

-- TASK 1: Bronze Data Lake Ingestion & Schema-on-Read Exploration

CREATE TABLE bronze_iot_streams(
ingest_id INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
raw_payload VARIANT,
recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);



INSERT INTO bronze_iot_streams(raw_payload,recorded_at)
SELECT TRY_PARSE_JSON(raw_record),timestamp 
FROM raw_iot_landing
WHERE TRY_PARSE_JSON(raw_record) IS NOT NULL;

SELECT COUNT(*) 
FROM bronze_iot_streams;


-- TASK 2: Dead-Letter Queue Quarantine Strategy
CREATE TABLE quarantine_iot_payloads(
quarantine_id INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
raw_record_text VARCHAR,
reason VARCHAR 
);

INSERT INTO quarantine_iot_payloads(raw_record_text,reason)
SELECT raw_record, 'MALFORMED_JSON_BODY'
FROM raw_iot_landing
WHERE TRY_PARSE_JSON(raw_record) IS NULL;

SELECT * FROM quarantine_iot_payloads;

-- TASK 3: Silver Layer ETL — Schema-on-Write Modeling & Computations
CREATE TABLE silver_customs_clearance(
shipment_id VARCHAR,
payload_id VARCHAR,
vehicle_id VARCHAR,
destination_country VARCHAR,
declared_value NUMBER(10,2),
duty_pct NUMBER(10,2),
duty_amount_due NUMBER(10,2),
border_code VARCHAR,
clearance_status VARCHAR
);

SELECT * FROM bronze_iot_streams;

INSERT INTO silver_customs_clearance
WITH cte AS (
SELECT raw_payload:data AS data,
        raw_payload
FROM bronze_iot_streams
)
SELECT data:shipment_id::STRING,
       raw_payload:payload_id::STRING,
       data:vehicle_id::STRING,
       data:destination_country::STRING,
       data:declared_value::NUMBER(10,2) AS declared_value,
       data:duty_pct::NUMBER(10,1) AS duty_pct,
       ROUND(declared_value * (duty_pct/100),2) AS DUTY_AMOUNT_DUE,
       data:border_clearance_code::STRING,
       data:clearance_status::STRING
FROM cte
WHERE raw_payload:payload_type = 'CUSTOMS';

SELECT * FROM silver_customs_clearance;

-- TASK 4: Gold Layer Strategic Aggregations
CREATE OR REPLACE TABLE gold_country_duty_summary(
dest_country VARCHAR,
total_cleared_val NUMBER(10,2),
total_dutities_collected NUMBER(10,2),
avg_duty_rate_pct NUMBER(10,2),
cleared_shipments NUMBER
);

INSERT INTO gold_country_duty_summary
SELECT destination_country,SUM(declared_value), SUM(duty_amount_due), ROUND(AVG(duty_pct),2),COUNT(*) 
FROM silver_customs_clearance
WHERE clearance_status = 'CLEARED'
GROUP BY destination_country
ORDER BY destination_country;

SELECT *
FROM gold_country_duty_summary;


-- TASK 5: Disaster Recovery via Snowflake Time-Travel Auditing

-- 1. Simulate corruption: Run an unauthorized SQL command setting all `CAN` shipments in `SILVER_CUSTOMS_CLEARANCE` to `CLEARANCE_STATUS = 'REJECTED'`.
UPDATE silver_customs_clearance
SET clearance_status = 'REJECTED'
WHERE destination_country = 'CAN';

SELECT * 
FROM silver_customs_clearance;

-- 2. Write a Time-Travel query using `AT (OFFSET => ...)` or `BEFORE` to view the original values.

SELECT
    query_id,
    query_text,
    execution_status,
    start_time,
    end_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION())
WHERE query_text ILIKE '%UPDATE silver_customs_clearance%' AND execution_status = 'SUCCESS'
ORDER BY start_time DESC;


SELECT * 
FROM silver_customs_clearance
BEFORE (STATEMENT=>'01c70676-000d-fa69-0002-0666000da4ae');

-- 3. Write a SQL recovery query restoring `SILVER_CUSTOMS_CLEARANCE` back to its uncorrupted state.
UPDATE silver_customs_clearance o
SET o.clearance_status = u.clearance_status
FROM (
        SELECT shipment_id,clearance_status
        FROM silver_customs_clearance 
        BEFORE (STATEMENT=> '01c70676-000d-fa69-0002-0666000da4ae')
        ) AS u
        
WHERE o.shipment_id = u.shipment_id 
        AND destination_country = 'CAN';


SELECT destination_country,COUNT_IF(clearance_status = 'CLEARED'),COUNT_IF(clearance_status='REJECTED')
FROM silver_customs_clearance
GROUP BY destination_country;


-- TASK 6: End-to-End Pipeline Lineage & Reconciliation Audit
WITH bronze AS (
    SELECT  SUM(raw_payload:data:declared_value::NUMBER(10,2)) AS BRONZE_GROSS_TOTAL
    FROM bronze_iot_streams 
),
silver AS (
    SELECT  SUM(declared_value) AS SILVER_GROSS_TOTAL
    FROM silver_customs_clearance
),
gold AS (
    SELECT  SUM(total_cleared_val) AS GOLD_GROSS_TOTAL
    FROM gold_country_duty_summary
),
silver_cleared AS (
    SELECT  SUM(declared_value) AS SILVER_CLEARED
    FROM silver_customs_clearance
    WHERE clearance_status = 'CLEARED'
)

SELECT  BRONZE_GROSS_TOTAL,
        SILVER_GROSS_TOTAL,
        GOLD_GROSS_TOTAL,
        IFF(BRONZE_GROSS_TOTAL = SILVER_GROSS_TOTAL AND GOLD_GROSS_TOTAL = SILVER_CLEARED, 'TRUE','FALSE' ) AS RECONCILED_FLAG 
FROM bronze
CROSS JOIN silver
CROSS JOIN gold
CROSS JOIN silver_cleared
;



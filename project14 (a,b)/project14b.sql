CREATE WAREHOUSE project_14
WITH 
WAREHOUSE_SIZE = "xsmall"
AUTO_SUSPEND = 60;
USE WAREHOUSE project_14;

CREATE DATABASE project14;
USE DATABASE project14;

CREATE SCHEMA project_14;
USE SCHEMA project_14;

CREATE FILE FORMAT json_format
type = 'json';

CREATE OR REPLACE STAGE payload_stage
file_format = json_format;

LIST @payload_stage;

CREATE TABLE bronze_payment_payloads(
raw_data VARIANT
);

COPY INTO bronze_payment_payloads 
FROM @payload_stage/bronze.json;


-- TASK 1: Bronze Layer Setup & Ingestion
SELECT COUNT(*) FROM bronze_payment_payloads;


-- TASK 2: Silver Layer ETL & Fee Computations
SELECT * FROM bronze_payment_payloads;

CREATE OR REPLACE TABLE silver_cleaned_transactions(
txn_id VARCHAR PRIMARY KEY, 
merchant_id INT,
merchant_name VARCHAR,
masked_card VARCHAR,
gross NUMBER(10,2),
processing_fee NUMBER(10,2),
net_settlement_amount NUMBER(10,2),
status VARCHAR
);

INSERT INTO silver_cleaned_transactions
SELECT raw_data:txn_id::STRING, raw_data:merchant_id::STRING,
    raw_data:merchant_name::STRING, 
    'XXXX-XXXX-XXXX-' || right(raw_data:card_number,4),
    raw_data:amount::NUMBER(10,2),
    raw_data:amount::NUMBER(10,2) * (raw_data:fee_pct::NUMBER(10,2) / 100) AS processing_fee,
    raw_data:amount::NUMBER(10,2) - processing_fee,
    raw_data:status::STRING
FROM bronze_payment_payloads;

SELECT * FROM silver_cleaned_transactions;


-- TASK 3: Gold Layer Financial Aggregations
CREATE TABLE gold_merchant_settlements(
merchant_id INT PRIMARY KEY,
merchant_name VARCHAR,
total_approved_gross NUMBER(10,2),
total_gateway_fees NUMBER(10,2),
total_net_payout NUMBER(10,2),
approved_count INT
);

INSERT INTO gold_merchant_settlements
SELECT merchant_id,merchant_name,SUM(gross),SUM(processing_fee),SUM(net_settlement_amount),COUNT(*)
FROM silver_cleaned_transactions
WHERE status = 'APPROVED'
GROUP BY merchant_id,merchant_name;

SELECT * FROM gold_merchant_settlements;

-- TASK 4: Data Corruption Simulation & Time-Travel Inspection
-- 1. Run UPDATE setting `TechZone` approved records to `STATUS = 'REFUNDED'`.
UPDATE silver_cleaned_transactions
SET status = 'REFUNDED'
WHERE merchant_name ='TechZone' AND status = 'APPROVED';

SELECT * 
FROM silver_cleaned_transactions 
WHERE merchant_name = 'TechZone';

-- 2. Execute Time-Travel query (`AT (OFFSET => ...)` or `BEFORE`) to view pre-corruption data.
SELECT txn_id, merchant_name, gross, status  
FROM silver_cleaned_transactions
at(offset=> -60*13)
WHERE merchant_name = 'TechZone';


-- TASK 5: Time-Travel Recovery Execution
-- - Revert corrupted statuses back to `APPROVED` using Time-Travel data.
UPDATE silver_cleaned_transactions s
SET status = 'APPROVED'
WHERE s.txn_id IN (SELECT txn_id FROM silver_cleaned_transactions at(offset=>-60*13) WHERE merchant_name = 'TechZone' AND status = 'APPROVED');

SELECT * 
FROM silver_cleaned_transactions
WHERE merchant_name = 'TechZone';

SELECT merchant_name, COUNT_IF(status='APPROVED'), COUNT_IF(status = 'REFUNDED')
FROM silver_cleaned_transactions
where merchant_name='TechZone'
GROUP BY merchant_name;


-- TASK 6: End-to-End Pipeline Reconciliation Audit
-- - Write a reconciliation audit query confirming gross totals across all three layers.
WITH bronze AS
(SELECT SUM(raw_data:amount) AS  BRONZE_GROSS_SUM 
FROM bronze_payment_payloads),

silver AS 
(SELECT SUM(gross) AS SILVER_GROSS_SUM  
FROM silver_cleaned_transactions),

gold AS 
(SELECT SUM(total_approved_gross) AS  GOLD_GROSS_SUM
FROM gold_merchant_settlements),

approve_silver AS (
SELECT SUM(gross) AS silver_approved
FROM silver_cleaned_transactions
WHERE status = 'APPROVED'
)

SELECT BRONZE_GROSS_SUM, SILVER_GROSS_SUM, GOLD_GROSS_SUM,

        iff(BRONZE_GROSS_SUM =SILVER_GROSS_SUM AND
            silver_approved = GOLD_GROSS_SUM ,'TRUE','FALSE')
        AS DATA_MATCH_FLAG
        
FROM bronze 
CROSS JOIN silver
CROSS JOIN gold
CROSS JOIN approve_silver;

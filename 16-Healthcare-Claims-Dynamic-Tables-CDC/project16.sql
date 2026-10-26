CREATE WAREHOUSE project16_wh
WITH 
WAREHOUSE_SIZE = "xsmall"
AUTO_SUSPEND = 60;
USE WAREHOUSE project16_wh;


-- TASK 1: Bronze Streaming Staging & Schema-on-Read Querying

-- - Create Database: `HEALTHCARE_PIPELINE_DB`
CREATE DATABASE healthcare_pipeline_db;
USE DATABASE healthcare_pipeline_db;


-- - Create Schema: `CLAIMS_CORE`
CREATE SCHEMA claims_core;
USE SCHEMA claims_core;

CREATE FILE FORMAT text_format
type = csv 
field_delimiter = NONE 
record_delimiter = '\n'
skip_header = 0;

CREATE OR REPLACE STAGE healthcare_stage
file_format = text_format;

CREATE TABLE raw_file_landing(
raw_text STRING
);

COPY INTO raw_file_landing
FROM @healthcare_stage;

SELECT * FROM raw_file_landing;


-- - Create Bronze table `BRONZE_RAW_CLAIMS` (`INGEST_ID`, `PAYLOAD` VARIANT, `LOADED_AT`).
CREATE OR REPLACE TABLE bronze_raw_claims(
ingest_id INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
payload VARIANT,
loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- - Create a Snowflake Stream `STRM_BRONZE_CLAIMS` on `BRONZE_RAW_CLAIMS`.
CREATE OR REPLACE STREAM strm_bronze_claims
ON TABLE bronze_raw_claims;

-- - Ingest valid JSON payloads from Batch 1, Batch 2, and Batch 3.
INSERT INTO bronze_raw_claims(payload)
SELECT TRY_PARSE_JSON(raw_text)
FROM raw_file_landing
WHERE TRY_PARSE_JSON(raw_text) IS NOT NULL;

SELECT * FROM bronze_raw_claims;
SELECT COUNT(*) FROM bronze_raw_claims;


-- TASK 2: Error Handling & Dead-Letter Isolation

-- - Create table `QUARANTINE_CLAIMS_PAYLOADS` (`QUARANTINE_ID`, `RAW_RECORD_TEXT`, `REASON`).
CREATE OR REPLACE TABLE quarantine_claims_payloads(
quarantine_id INT PRIMARY KEY AUTOINCREMENT START 1 ORDER,
raw_record_text STRING,
reason STRING
);

INSERT INTO quarantine_claims_payloads(raw_record_text,reason)
SELECT raw_text, 'MALFORMED_JSON_BODY'
FROM raw_file_landing
WHERE TRY_PARSE_JSON(raw_text) IS NULL;

SELECT * FROM quarantine_claims_payloads;


-- TASK 3: Silver Layer — Real-Time CDC via Stream Tracking

-- - Create Silver base table `SILVER_CLAIMS_TRANSACTIONS` with columns:
--   * `CLAIM_ID`, `SUBMITTED_AT`, `PATIENT_ID`, `PROVIDER_ID`, `DIAGNOSIS_CODE`, `BILLED_AMOUNT`, `COPAY_AMOUNT`, `NET_PAYABLE_AMOUNT`, `STATUS`

CREATE TABLE silver_claims_transactions(
claim_id VARCHAR,
submitted_at TIMESTAMP,
patient_id INT,
provider_id VARCHAR,
diagnosis_code VARCHAR,
billed_amount NUMBER(10,2),
copay_amount NUMBER(10,2),
net_payable_amount NUMBER(10,2),
status VARCHAR
);

INSERT INTO silver_claims_transactions
SELECT * EXCLUDE(rnk)
FROM (
        SELECT  payload:claim_id::STRING AS claim_id,
        payload:submitted_at::TIMESTAMP AS submitted_at,
        payload:patient_id::INT,
        payload:provider_id::STRING,
        payload:diagnosis_code::STRING,
        payload:billed_amount::NUMBER(10,2) AS billed_amount,
        payload:copay_amount::NUMBER(10,2) AS copay_amount,
        billed_amount - copay_amount,
        payload:status::STRING,
        ROW_NUMBER() OVER(PARTITION BY claim_id ORDER BY submitted_at DESC) AS rnk
        FROM bronze_raw_claims
        )
WHERE rnk = 1;

SELECT * FROM silver_claims_transactions;


-- TASK 4: Declarative Pipeline Automation — Dynamic Table Setup

-- - Create a Dynamic Table `DT_PROVIDER_FINANCIAL_SUMMARY` with `TARGET_LAG = '1 minute'` and `WAREHOUSE = COMPUTE_WH`.
-- - Compute financial summaries strictly for `STATUS = 'APPROVED'` claims grouped by `PROVIDER_ID`.

CREATE DYNAMIC TABLE dt_provider_financial_summary
TARGET_LAG = '1 minute'
WAREHOUSE = project16_wh
AS 
SELECT provider_id,
    SUM(billed_amount) AS total_billed_amount,
    SUM(copay_amount) AS total_copay_collect,
    SUM(net_payable_amount) AS total_net_payable,
    COUNT(*) AS approved_claims
FROM silver_claims_transactions
WHERE status = 'APPROVED'
GROUP BY provider_id;


SELECT * 
FROM dt_provider_financial_summary
ORDER BY provider_id; 


-- TASK 5: Dynamic Table Refresh Monitoring & DAG Audit
-- - Query `INFORMATION_SCHEMA.DYNAMIC_TABLE_GRAPH_HISTORY` / `DYNAMIC_TABLE_REFRESH_HISTORY` 
-- to verify that `DT_PROVIDER_FINANCIAL_SUMMARY` executed incremental refreshes.
SELECT
    name AS dynamic_table_name,
    refresh_action,
    state AS qualified_status,
    refresh_trigger,
    refresh_start_time,
    refresh_end_time
FROM TABLE(
    INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME => 'DT_PROVIDER_FINANCIAL_SUMMARY'
    )
)
ORDER BY refresh_start_time DESC;

-- TASK 6: End-to-End Pipeline Lineage & Reconciliation Audit
-- - Write an audit query confirming total billed values across Bronze, Silver, and Gold (Dynamic Table) 
--   layers to ensure complete data integrity across transformations.

WITH bronze AS (
SELECT SUM(payload:billed_amount::NUMBER(10,2)) AS  BRONZE_GROSS_TOTAL
FROM bronze_raw_claims
),
silver AS (
SELECT SUM(billed_amount) AS  SILVER_GROSS_TOTAL
FROM silver_claims_transactions
),
gold AS (
SELECT SUM(TOTAL_BILLED_AMOUNT) AS  GOLD_GROSS_TOTAL
FROM dt_provider_financial_summary
),
silver_approved AS (
SELECT SUM(billed_amount) AS  silver_app
FROM silver_claims_transactions
WHERE status = 'APPROVED'
),
bronze_de AS (
SELECT SUM(bill) AS bronze_deduplicate
FROM 
    (SELECT payload:claim_id::STRING,payload:billed_amount::NUMBER(10,2) AS bill,ROW_NUMBER() OVER(PARTITION BY payload:claim_id ORDER BY payload:submitted_at DESC) AS rnk
    FROM bronze_raw_claims)t
WHERE rnk = 1
)
SELECT  BRONZE_GROSS_TOTAL,
        SILVER_GROSS_TOTAL ,
        GOLD_GROSS_TOTAL,
        IFF(bronze_deduplicate = SILVER_GROSS_TOTAL AND GOLD_GROSS_TOTAL = silver_app, 'TRUE', 'FALSE')
FROM bronze
CROSS JOIN silver 
CROSS JOIN gold
CROSS JOIN silver_approved
CROSS JOIN bronze_de;

CREATE WAREHOUSE financial_governance_wh
WITH 
auto_suspend= 60
warehouse_size = 'xsmall';
USE WAREHOUSE financial_governance_wh;

-- TASK 1: Bronze Storage Setup & Error Isolation
-- - Create Database: `FINANCIAL_GOVERNANCE_DB`
CREATE DATABASE financial_governance_db;
USE DATABASE financial_governance_db;

-- - Create Schema: `WEALTH_CORE`
CREATE SCHEMA wealth_schema;
USE SCHEMA wealth_schema;

CREATE FILE FORMAT text_format
type = csv 
field_delimiter = NONE 
skip_header = 0
record_delimiter = '\n';

CREATE STAGE finance_stage
file_format= text_format;

CREATE TABLE raw_landing(
raw_text STRING,
loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP() 
);

COPY INTO raw_landing (raw_text) 
FROM @finance_stage;

SELECT * FROM raw_landing;

-- - Create Bronze table `BRONZE_BANK_PAYLOADS` (`INGEST_ID`, `PAYLOAD` VARIANT, `LOADED_AT`).
CREATE TABLE bronze_bank_payloads(
ingest_id INT PRIMARY KEY AUTOINCREMENT START 1 ORDER,
raw_data VARIANT,
loaded_at TIMESTAMP 
);


INSERT INTO bronze_bank_payloads (raw_data, loaded_at)
SELECT TRY_PARSE_JSON(raw_text),loaded_at
FROM raw_landing
WHERE TRY_PARSE_JSON(raw_text) IS NOT NULL;

SELECT COUNT(*) FROM bronze_bank_payloads;

-- - Ingest valid payloads and isolate corrupt records into `QUARANTINE_GOVERNANCE_PAYLOADS`.
CREATE OR REPLACE TABLE quarantine_governance_payloads(
ingest_id INT PRIMARY KEY AUTOINCREMENT, 
raw_text STRING,
reason STRING
);

INSERT INTO quarantine_governance_payloads (raw_text,reason)
SELECT raw_text,'MALFORMED_JSON_BODY'
FROM raw_landing
WHERE TRY_PARSE_JSON(raw_text) IS NULL;

SELECT * FROM bronze_bank_payloads;
SELECT * FROM quarantine_governance_payloads;


-- TASK 2: Silver Layer Setup & RBAC Role Provisioning
-- - Create Silver table `SILVER_BANK_TRANSACTIONS`:
--   * `TXN_ID`, `CLIENT_ID`, `CLIENT_SSN`, `REGION`, `ACCOUNT_NO`, `AMOUNT`, `STATUS`, `AML_RISK_SCORE`
CREATE TABLE silver_bank_transactions(
txn_id VARCHAR,
client_id INT,
client_ssn VARCHAR,
region VARCHAR,
account_no VARCHAR,
amount NUMBER(10,2),
status VARCHAR,
aml_risk_score VARCHAR
);

INSERT INTO silver_bank_transactions
SELECT raw_data:txn_id::STRING,
        raw_data:client_id::INT,
        raw_data:client_ssn::STRING,
        raw_data:region::STRING,
        raw_data:account_no::STRING,
        raw_data:amount::NUMBER(10,2),
        raw_data:status::STRING,
        raw_data:aml_risk_score::STRING
FROM bronze_bank_payloads;

SELECT * FROM silver_bank_transactions;

-- - Create RBAC Roles: `COMPLIANCE_OFFICER`, `NA_ANALYST`, `EU_ANALYST`.
-- - Grant appropriate SELECT privileges to each role.
CREATE  ROLE compliance_officer;
CREATE ROLE na_analyst;
CREATE ROLE eu_analyst;

GRANT USAGE ON DATABASE financial_governance_db
TO ROLE compliance_officer;

GRANT USAGE ON SCHEMA financial_governance_db.wealth_schema
TO ROLE compliance_officer;

GRANT SELECT ON ALL TABLES IN SCHEMA financial_governance_db.wealth_schema
TO ROLE compliance_officer;

-- NA_ANALYST
GRANT USAGE ON DATABASE financial_governance_db
TO ROLE na_analyst;

GRANT USAGE ON SCHEMA financial_governance_db.wealth_schema
TO ROLE na_analyst;

GRANT SELECT ON TABLE financial_governance_db.wealth_schema.silver_bank_transactions
TO ROLE na_analyst;

GRANT USAGE ON DATABASE financial_governance_db
TO ROLE eu_analyst;

GRANT USAGE ON SCHEMA financial_governance_db.wealth_schema
TO ROLE eu_analyst;

GRANT SELECT ON TABLE financial_governance_db.wealth_schema.silver_bank_transactions
TO ROLE eu_analyst;

GRANT ROLE compliance_officer TO USER MMAR;

GRANT ROLE eu_analyst TO USER MMAR;

GRANT ROLE na_analyst TO USER MMAR;

-- TASK 3: Dynamic Data Masking (DDM) Implementation
CREATE OR REPLACE MASKING POLICY mask_ssn
AS (ssn STRING)
RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() = 'COMPLIANCE_OFFICER'
            THEN ssn  
        ELSE 
            '***-**-' || RIGHT(ssn,4)
    END;

CREATE OR REPLACE MASKING POLICY mask_account
AS (account_no STRING)
RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() = 'COMPLIANCE_OFFICER'
            THEN account_no
        ELSE 
            'ACT-****'
    END;


ALTER TABLE silver_bank_transactions
MODIFY COLUMN client_ssn
SET MASKING POLICY mask_ssn;

ALTER TABLE silver_bank_transactions
MODIFY COLUMN account_no
SET MASKING POLICY mask_account;

-- (Queried as `NA_ANALYST`):
USE ROLE na_analyst;
SELECT * FROM SILVER_BANK_TRANSACTIONS;
SELECT CURRENT_ROLE();
USE ROLE ACCOUNTADMIN;

-- - Create Row Access Policy `RAP_REGION_POLICY` on `REGION`:
CREATE OR REPLACE ROW ACCESS POLICY rap_region_policy
AS (region STRING)
RETURNS BOOLEAN ->
    CASE CURRENT_ROLE()
    
        WHEN 'COMPLIANCE_OFFICER'
            THEN TRUE
        WHEN 'EU_ANALYST'
            THEN region = 'EU'
        WHEN 'NA_ANALYST'
            THEN region = 'NA'
        ELSE 
            FALSE 
    END;

ALTER TABLE silver_bank_transactions
ADD ROW ACCESS POLICY rap_region_policy ON (region);

-- (Queried as `EU_ANALYST`)
USE ROLE compliance_officer;
USE ROLE na_analyst;
USE ROLE eu_analyst;

SELECT * 
FROM silver_bank_transactions; 


-- TASK 5: Secure Data Sharing & Clean Room Audit View
USE ROLE ACCOUNTADMIN;

CREATE SECURE VIEW secure_gold_external_audit_summary AS 
SELECT 
        region,
        SUM(amount) AS TOTAL_SETTLED_VAL ,
        COUNT(*) AS SETTLED_TXN_COUNT  ,
        ROUND(AVG(amount),2) AS AVG_SETTLED_AMOUNT
FROM silver_bank_transactions
WHERE status = 'SETTLED'
GROUP BY region;


SELECT * 
FROM secure_gold_external_audit_summary;


-- TASK 6: End-to-End Governance Audit & Lineage Reconciliation
WITH reconciliation AS (
    SELECT
        (SELECT SUM(raw_data:amount::NUMBER(10,2))
         FROM bronze_bank_payloads) AS bronze_total,

        (SELECT SUM(amount)
         FROM silver_bank_transactions) AS silver_total,

        (SELECT SUM(CASE
                        WHEN status = 'SETTLED'
                        THEN amount
                        ELSE 0
                    END)
         FROM silver_bank_transactions) AS silver_settled_total,

        (SELECT SUM(total_settled_val)
         FROM secure_gold_external_audit_summary) AS gold_total
)
SELECT
    bronze_total,
    silver_total,
    silver_settled_total,
    gold_total,

    CASE
        WHEN bronze_total = silver_total
         AND silver_settled_total = gold_total
        THEN TRUE
        ELSE FALSE
    END AS reconciliation_flag

FROM reconciliation;

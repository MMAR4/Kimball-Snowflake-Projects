CREATE OR REPLACE WAREHOUSE project_18_wh
WITH 
WAREHOUSE_SIZE = 'xsmall'
AUTO_SUSPEND= 60;
USE WAREHOUSE project_18_wh;

-- TASK 1: Environment Setup & Raw Telemetry Ingestion

CREATE DATABASE CLEANROOM_SHARED_DB;
USE DATABASE CLEANROOM_SHARED_DB;

CREATE SCHEMA PARTNER_TELEMETRY;
USE SCHEMA PARTNER_TELEMETRY;

CREATE FILE FORMAT json_format
type = json;

CREATE OR REPLACE STAGE project_18_stage
FILE_FORMAT = json_format;

CREATE TABLE BRONZE_RETAIL_TRANSACTIONS(
raw_data VARIANT
);

CREATE TABLE BRONZE_AD_EXPOSURES(
raw_data VARIANT
);

COPY INTO BRONZE_RETAIL_TRANSACTIONS
FROM @project_18_stage/pos.json;

COPY INTO BRONZE_AD_EXPOSURES
FROM @project_18_stage/rae.json;

SELECT COUNT(*) FROM BRONZE_RETAIL_TRANSACTIONS;


-- TASK 2: Silver Clean Room Overlap & Aggregation Layer

CREATE TABLE SILVER_ATTRIBUTION_MATCH(
POS_ID STRING,
STORE_ID STRING,
CAMPAIGN_NAME STRING,
CHANNEL STRING,
BASKET_VALUE STRING,
CONVERSION_HOURS INT
);

SELECT * FROM BRONZE_RETAIL_TRANSACTIONS;
SELECT * FROM BRONZE_AD_EXPOSURES;


INSERT INTO SILVER_ATTRIBUTION_MATCH
WITH cte1 AS (SELECT raw_data AS rd1 FROM BRONZE_RETAIL_TRANSACTIONS),
cte2 AS (SELECT raw_data AS rd2 FROM BRONZE_AD_EXPOSURES)

SELECT  rd1:pos_id::STRING,
        rd1:store_id::STRING,
        rd2:campaign_name::STRING,
        rd2:channel::STRING,
        rd1:basket_value::NUMBER(10,2),
        DATEDIFF('hour',rd2:timestamp, rd1:timestamp)
        
FROM cte1
JOIN cte2
ON cte1.rd1:hashed_email = cte2.rd2:hashed_email;

SELECT * FROM silver_attribution_match;


-- TASK 3: Aggregate-Only Differential Privacy View (Clean Room Governance)
CREATE SECURE VIEW SECURE_GOLD_CAMPAIGN_ATTRIBUTION_PERFORMANCE AS 
SELECT  campaign_name,
        channel,
        COUNT(*) AS coverted_user_count,
        SUM(basket_value) AS TOTAL_ATTRIBUTED_VAL,
        AVG(basket_value) AS AVG_BASKET_VALUE
FROM silver_attribution_match
GROUP BY campaign_name,channel
HAVING COUNT(DISTINCT POS_ID) >= 2;


-- TASK 4: Secure Data Share Creation & Privilege Assignment
CREATE SHARE SHARE_CPG_PARTNER_ANALYTICS;

GRANT USAGE ON DATABASE cleanroom_shared_db
TO SHARE SHARE_CPG_PARTNER_ANALYTICS;

GRANT USAGE ON SCHEMA cleanroom_shared_db.partner_telemetry
TO SHARE SHARE_CPG_PARTNER_ANALYTICS;

GRANT SELECT ON VIEW cleanroom_shared_db.partner_telemetry.secure_gold_campaign_attribution_performance
TO SHARE SHARE_CPG_PARTNER_ANALYTICS;

SHOW SHARES ;

-- TASK 5: Provisioning a Reader Account for Non-Snowflake Partners

CREATE MANAGED ACCOUNT CPG_READER_ACCT_01
ADMIN_NAME = reader_admin -- username
ADMIN_PASSWORD = 'Password******'
TYPE = READER;

SHOW MANAGED ACCOUNTS; --get account_url example https://fjfzjhm-cpg_reader_acct_01.snowflakecomputing.com 
-- login with account_url with username: reader_admin and password: Password******

ALTER SHARE SHARE_CPG_PARTNER_ANALYTICS
ADD ACCOUNTS = MK57963;

SHOW WAREHOUSES LIKE 'READER_WH'; 


-- TASK 6: End-to-End Clean Room Reconciliation & Compliance Check
SELECT
    COUNT(*) AS SILVER_MATCHED_RECORDS,
    SUM(BASKET_VALUE) AS SILVER_TOTAL_SALES
FROM SILVER_ATTRIBUTION_MATCH;

SELECT
    COUNT(*) AS GOLD_GROUP_COUNT,
    SUM(TOTAL_ATTRIBUTED_VAL) AS GOLD_TOTAL_SALES
FROM SECURE_GOLD_CAMPAIGN_ATTRIBUTION_PERFORMANCE;

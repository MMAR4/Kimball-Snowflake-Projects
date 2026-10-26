CREATE WAREHOUSE pro14_wh
WITH 
WAREHOUSE_SIZE = "small"
AUTO_SUSPEND = 60;
USE WAREHOUSE pro14_wh;

CREATE DATABASE ecommerce_db;
USE DATABASE ecommerce_db;

CREATE SCHEMA ecommerce_schema;
USE SCHEMA ecommerce_schema;

CREATE FILE FORMAT json_format
type = 'json';

CREATE STAGE raw_event
file_format = json_format;

CREATE OR REPLACE TABLE lake_raw_events(
raw_data VARIANT
);

COPY INTO lake_raw_events 
FROM @raw_event
file_format = (format_name = 'json_format');

-- TASK 1: Data Lake Ingestion
SELECT COUNT(*) 
FROM lake_raw_events
WHERE raw_data:event_id::STRING LIKE 'EVT-%';

-- TASK 2: Schema-on-Read Ingestion & Extraction
SELECT raw_data:event_id::STRING AS EVENT_ID, 
       raw_data:timestamp::timestamp AS EVENT_TIME,
       raw_data:user_id::NUMBER AS USER_ID,
       raw_data:action::STRING AS ACTION,
       raw_data:order:total::NUMBER(10,2) AS ORDER_TOTAL,
       raw_data:promo_code::STRING AS PROMO_CODE
FROM lake_raw_events
ORDER BY raw_data:event_id;


-- TASK 3: Schema-on-Read Financial Analysis
SELECT raw_data:event_id::STRING AS event_id,
       raw_data:order:total::NUMBER(10,2) AS order_total,
       raw_data:order:shipping_cost::NUMBER(10,2) AS shipping_cost,
       raw_data:order:tax::NUMBER(10,2) AS tax,
       COALESCE(raw_data:discount_amount::NUMBER(10,2),0) AS discount_amount,
       -- raw_data:order:total - raw_data:order:shipping_cost - raw_data:order:tax - COALESCE(raw_data:discount_amount, 0) AS net_revenue,
       (ORDER_TOTAL-SHIPPING_COST-TAX-DISCOUNT_AMOUNT) as NET_REVENUE
FROM lake_raw_events
WHERE net_revenue::NUMBER(10,2) > 0
ORDER BY event_id;



-- TASK 4: Funnel & Conversion Key Metrics
SELECT COUNT(*) AS TOTAL_EVENTS,
    COUNT_IF(raw_data:action::STRING = 'purchase') AS Total_purchases,
    COALESCE(Total_purchases/TOTAL_EVENTS * 100,2),
    SUM(CASE WHEN raw_data:action = 'purchase' 
            AND raw_data:order:total> 0 
        THEN raw_data:order:total
        ELSE  0
        END) AS TOTAL_GROSS_REVENUE,
    ROUND(TOTAL_GROSS_REVENUE/Total_purchases,0) AS AVERAGE_ORDER_VALUE
FROM lake_raw_events 
WHERE raw_data:event_id::STRING LIKE 'EVT-%';

SELECT * FROM lake_raw_events;


-- TASK 5: Data Warehouse Backfill (Schema-on-Write)
-- - Insert valid extracted payloads into `DW_STRUCTURED_EVENTS`.
CREATE OR REPLACE TABLE dw_structured_events(
event_id varchar,
event_time timestamp,
user_id int,
page varchar,
action varchar,
order_total number(12,2),
shipping_cost number(12,2),
tax number(12,2),
items int,
promo_code varchar,
discount_amount number(12,2),
net_revenue number(12,2)
);

INSERT INTO dw_structured_events 
SELECT raw_data:event_id::VARCHAR,
       raw_data:timestamp::TIMESTAMP,
       raw_data:user_id::INT,
       raw_data:page::VARCHAR,
       raw_data:action::VARCHAR,
       raw_data:order:total::NUMBER(10,2) AS order_total,
       raw_data:order:shipping_cost::NUMBER(10,2) AS shipping_cost, 
       raw_data:order.tax::NUMBER(10,2) AS tax,
       raw_data:order.items::INT ,
       raw_data:promo_code::VARCHAR,
       raw_data:discount_amount::NUMBER(12,2) AS discount_amount,
       (ORDER_TOTAL-SHIPPING_COST-TAX-DISCOUNT_AMOUNT) as NET_REVENUE
FROM lake_raw_events
WHERE raw_data:event_id LIKE 'EVT-%';

SELECT * FROM dw_structured_events;

SELECT COUNT(*),SUM(net_revenue)
FROM dw_structured_events;


-- TASK 6: Data Integrity & Error Quarantine Strategy
-- - Identify and move corrupt non-JSON records into `QUARANTINE_RAW_EVENTS`.
CREATE TABLE QUARANTINE_RAW_EVENTS(
quarantine_id INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
raw_record_text VARCHAR,
reason VARCHAR
);

INSERT INTO QUARANTINE_RAW_EVENTS (raw_record_text,reason)
SELECT raw_data:event_id, 'MALFORMED_JSON_BODY' AS reason
FROM lake_raw_events
WHERE raw_data:event_id NOT LIKE 'EVT-%';

SELECT * FROM QUARANTINE_RAW_EVENTS;

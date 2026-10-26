CREATE WAREHOUSE healthcare_wh
WITH 
WAREHOUSE_SIZE = "xsmall"
AUTO_SUSPEND = 60;

USE WAREHOUSE healthcare_wh;

-- TASK 1 — Create Environment Context
CREATE DATABASE healthcare_db;
USE DATABASE healthcare_db;

CREATE SCHEMA schema_compare_lab;
USE SCHEMA schema_compare_lab;

CREATE FILE FORMAT csv_format 
type = 'csv'
field_delimiter = ','
skip_header = 2
skip_blank_lines = TRUE;

CREATE OR REPLACE STAGE healthcare_stage
file_format = csv_format;


CREATE TABLE HOSPITALS (
    HOSPITAL_ID NUMBER,
    HOSPITAL_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    NETWORK_ID NUMBER,
    NETWORK_NAME VARCHAR(100),
    NETWORK_DIRECTOR VARCHAR(100)
);


CREATE TABLE TREATMENTS (
    TREATMENT_ID NUMBER,
    TREATMENT_NAME VARCHAR(100),
    DIAGNOSIS_GROUP_ID VARCHAR(50),
    DIAGNOSIS_GROUP_NAME VARCHAR(50),
    STANDARD_COST NUMBER(12,2)
);


CREATE TABLE PATIENTS (
    PATIENT_ID NUMBER,
    PATIENT_NAME VARCHAR(100),
    GENDER VARCHAR(20),
    AGE NUMBER,
    CITY VARCHAR(50)
);


CREATE TABLE INSURANCE_CLAIMS (
    CLAIM_ID VARCHAR(50),
    CLAIM_DATE DATE,
    PATIENT_ID NUMBER,
    HOSPITAL_ID NUMBER,
    TREATMENT_ID NUMBER,
    CLAIMED_AMOUNT NUMBER(12,2),
    APPROVED_AMOUNT NUMBER(12,2)
);

COPY INTO HOSPITALS
FROM @healthcare_stage
FILES = ('hospital.csv')
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');


COPY INTO TREATMENTS
FROM @healthcare_stage
FILES = ('treatment.csv')
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');


COPY INTO PATIENTS
FROM @healthcare_stage
FILES = ('patients.csv')
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');


COPY INTO INSURANCE_CLAIMS
FROM @healthcare_stage
FILES = ('insurance_claims.csv')
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');

-- TASK 2 — Build Star Schema Denormalized Hospital Dimension (`STAR_DIM_HOSPITAL`)
CREATE OR REPLACE TABLE star_dim_hospital(
hospital_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
hospital_id INT UNIQUE NOT NULL,
hospital_name VARCHAR,
city VARCHAR,
state VARCHAR,
network_id INT,
network_name VARCHAR,
network_director VARCHAR
);


-- TASK 3 — Build Star Schema Denormalized Treatment Dimension (`STAR_DIM_TREATMENT`)
CREATE OR REPLACE TABLE star_dim_treatment(
treatment_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
treatment_id INT UNIQUE NOT NULL,
treatment_name VARCHAR,
diagnosis_group_id VARCHAR,
diagnosis_group_name VARCHAR,
standard_cost NUMBER (10,2)
);

-- TASK 4 — Load Star Schema Dimension Data
COPY INTO star_dim_hospital (hospital_id,hospital_name,city,state,network_id,network_name,network_director)
FROM @healthcare_stage/hospital.csv;

COPY INTO star_dim_treatment (treatment_id,treatment_name,diagnosis_group_id,diagnosis_group_name,standard_cost)
FROM @healthcare_stage/treatment.csv;

SHOW tables;
-- TASK 5 — Build & Load Star Schema Claims Fact Table (`STAR_FACT_CLAIMS`)
CREATE OR REPLACE TABLE star_fact_claims(
claim_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER ,
claim_id VARCHAR,
claim_date DATE,
patient_id NUMBER,
hospital_key NUMBER,
treatment_key NUMBER,
claimed_amount NUMBER(10,2),
approved_amount NUMBER(10,2),

FOREIGN KEY (hospital_key) REFERENCES star_dim_hospital(hospital_key),
FOREIGN KEY (treatment_key) REFERENCES star_dim_treatment(treatment_key)
);

INSERT INTO star_fact_claims (claim_id,claim_date,patient_id,hospital_key,treatment_key,claimed_amount,approved_amount)
SELECT i.claim_id,i.claim_date, i.patient_id, h.hospital_key, t.treatment_key, i.claimed_amount, i.approved_amount
FROM insurance_claims i
JOIN star_dim_hospital h 
ON i.hospital_id = h.hospital_id
JOIN star_dim_treatment t 
ON i.treatment_id = t.treatment_id;

SELECT * FROM star_fact_claims;


-- TASK 6 — Build Normalized Snowflake Schema Hospital Hierarchy
CREATE OR REPLACE TABLE snow_dim_network (
network_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
network_id INT NOT NULL,
network_name VARCHAR,
network_director VARCHAR
);

CREATE OR REPLACE TABLE snow_dim_hospital(
hospital_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
hospital_id INT NOT NULL,
hospital_name VARCHAR,
city VARCHAR,
state VARCHAR,
network_key INT REFERENCES snow_dim_network(network_key)
);


-- TASK 7 — Build Normalized Snowflake Schema Treatment Hierarchy
CREATE OR REPLACE TABLE snow_dim_diagnosis_group (
diagnosis_group_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
diagnosis_group_id VARCHAR,
diagnosis_group_name VARCHAR
);

CREATE OR REPLACE TABLE snow_dim_treatment(
treatment_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
treatment_id INT NOT NULL,
treatment_name VARCHAR,
standard_cost INT,
diagnosis_group_key INT,
FOREIGN KEY (diagnosis_group_key) REFERENCES snow_dim_diagnosis_group (diagnosis_group_key)
);


-- TASK 8 — Populate Snowflake Schema Normalized Hierarchies
INSERT INTO snow_dim_network (network_id, network_name, network_director)
SELECT DISTINCT network_id, network_name, network_director
FROM star_dim_hospital;

INSERT INTO snow_dim_hospital(hospital_id,hospital_name, city,state, network_key)
SELECT h.hospital_id,h.hospital_name, h.city,h.state, n.network_key
FROM star_dim_hospital h
JOIN snow_dim_network n 
ON h.network_id = n.network_id;

INSERT INTO snow_dim_diagnosis_group(diagnosis_group_id,diagnosis_group_name)
SELECT DISTINCT diagnosis_group_id,diagnosis_group_name
FROM star_dim_treatment;

INSERT INTO snow_dim_treatment(treatment_id, treatment_name, standard_cost, diagnosis_group_key)
SELECT treatment_id, treatment_name, standard_cost,g.diagnosis_group_key
FROM star_dim_treatment t 
JOIN snow_dim_diagnosis_group g 
ON t.diagnosis_group_id = g.diagnosis_group_id;


-- TASK 9 — Build & Load Snowflake Schema Claims Fact Table (`SNOW_FACT_CLAIMS`)
CREATE OR REPLACE TABLE snow_fact_claims (
claim_key INT PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
claim_id VARCHAR NOT NULL,
claim_date DATE,
patient_id INT,
hospital_key INT,
treatment_key INT,
claimed_amount NUMBER(10,2),
approved_amount NUMBER(10,2),

FOREIGN KEY (hospital_key) REFERENCES snow_dim_hospital(hospital_key),
FOREIGN KEY (treatment_key) REFERENCES snow_dim_treatment(treatment_key)
);

INSERT INTO snow_fact_claims(claim_id, claim_date, patient_id, hospital_key, treatment_key, claimed_amount, approved_amount)
SELECT c.claim_id, c.claim_date,c.patient_id, h.hospital_key, t.treatment_key , c.claimed_amount, c.approved_amount
FROM insurance_claims c 
JOIN snow_dim_hospital h
ON c.hospital_id = h.hospital_id
JOIN snow_dim_treatment t 
ON c.treatment_id = t.treatment_id ;


-- TASK 10 — Star Schema Specialty Claims Analysis (Flat 1-Hop Query)
SELECT  DIAGNOSIS_GROUP_NAME,
        SUM(claimed_amount) AS TOTAL_CLAIMED_AMOUNT,
        SUM(approved_amount) AS TOTAL_APPROVED_AMOUNT
FROM star_fact_claims c
JOIN star_dim_treatment t 
ON c.treatment_key = t.treatment_key
GROUP BY DIAGNOSIS_GROUP_NAME
ORDER BY TOTAL_CLAIMED_AMOUNT DESC;

SELECT * FROM star_dim_treatment;

-- TASK 11 — Snowflake Schema Specialty Claims Analysis (Multi-Hop Join Query)
SELECT  DIAGNOSIS_GROUP_NAME,
        SUM(c.claimed_amount) AS TOTAL_CLAIMED_AMOUNT,
        SUM(c.approved_amount) AS TOTAL_APPROVED_AMOUNT
FROM snow_fact_claims c
JOIN snow_dim_treatment t 
ON c.treatment_key = t.treatment_key
JOIN snow_dim_diagnosis_group d 
ON t.DIAGNOSIS_GROUP_KEY = d.diagnosis_group_key
GROUP BY DIAGNOSIS_GROUP_NAME
ORDER BY TOTAL_CLAIMED_AMOUNT DESC;


-- TASK 12 — Hospital Network Director Performance Report
SELECT h.network_director, COUNT(*),SUM(c.approved_amount) AS TOTAL_APPROVED_AMOUNT
FROM star_dim_hospital h 
JOIN star_fact_claims c 
ON h.hospital_key = c.hospital_key
GROUP BY h.network_director;

SELECT n.network_director, COUNT(*),SUM(c.approved_amount) AS TOTAL_APPROVED_AMOUNT
FROM snow_dim_network n 
JOIN snow_dim_hospital h 
ON n.network_key = h.network_key 
JOIN snow_fact_claims c 
ON h.hospital_key = c.hospital_key
GROUP BY n.network_director
;

-- TASK 13 — Data Anomaly Analysis: Master Data Update Test (Network Director Update)

UPDATE star_dim_hospital h 
SET h.network_director = 'Dr. Anand'
WHERE network_id = 10 ;

UPDATE snow_dim_network n
SET network_director = 'Dr. Anand'
WHERE network_id = 10 ;


-- TASK 14 — Full Architecture Record Audit & Schema Comparison
SELECT 'Star Schema' AS SCHEMA_TYPE,'STAR_DIM_HOSPITAL' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM star_dim_hospital
UNION ALL 
SELECT 'Star Schema' AS SCHEMA_TYPE,'STAR_DIM_TREATMENT' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM STAR_DIM_TREATMENT
UNION ALL 
SELECT 'Star Schema' AS SCHEMA_TYPE,'STAR_FACT_CLAIMS' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM STAR_FACT_CLAIMS
UNION ALL 
SELECT 'Snowflake Schema' AS SCHEMA_TYPE,'SNOW_DIM_NETWORK' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM SNOW_DIM_NETWORK
UNION ALL 
SELECT 'Snowflake Schema' AS SCHEMA_TYPE,'SNOW_DIM_HOSPITAL' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM SNOW_DIM_HOSPITAL
UNION ALL 
SELECT 'Snowflake Schema' AS SCHEMA_TYPE,'SNOW_DIM_DIAGNOSIS_GROUP' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM SNOW_DIM_DIAGNOSIS_GROUP
UNION ALL 
SELECT 'Snowflake Schema' AS SCHEMA_TYPE,'SNOW_DIM_TREATMENT' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM SNOW_DIM_TREATMENT
UNION ALL 
SELECT 'Snowflake Schema' AS SCHEMA_TYPE,'SNOW_FACT_CLAIMS' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT
FROM SNOW_FACT_CLAIMS;


CREATE WAREHOUSE project19b_wh
WITH 
WAREHOUSE_SIZE = 'xsmall'
AUTO_SUSPEND = 60;

USE WAREHOUSE project19b_wh;

CREATE DATABASE project19b_db;
USE DATABASE project19b_db;

CREATE SCHEMA project19b_schema;
USE SCHEMA project19b_schema;

CREATE FILE FORMAT csv_format
type = 'csv'
field_delimiter = ','
skip_header = 1
skip_blank_lines=TRUE;

CREATE STAGE project19b_stage
file_format = csv_format;

CREATE TABLE FACTLESS_STAFF_COVERAGE(
shift_date DATE,
doctor_id STRING,
department_id STRING,
shift_type STRING
);

COPY INTO FACTLESS_STAFF_COVERAGE
FROM @project19b_stage
FILES = ('raw_doctor_roster.csv')
FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT);

SELECT COUNT(*) 
FROM FACTLESS_STAFF_COVERAGE;


-- TASK 2: Factless Coverage Analysis Query
-- - Write a query to find departments that had ZERO night shifts assigned on `2026-08-20`.
SELECT department_id,COUNT_IF(shift_type= 'NIGHT') 
FROM FACTLESS_STAFF_COVERAGE
WHERE shift_date = '2026-08-20'
GROUP BY department_id
HAVING COUNT_IF(shift_type='NIGHT') = 0;

-- METHOD 2
SELECT DISTINCT f.department_id, COALESCE(n.department_id,0)
FROM FACTLESS_STAFF_COVERAGE f
LEFT JOIN FACTLESS_STAFF_COVERAGE n
    ON f.department_id = n.department_id
    AND n.shift_date = '2026-08-20'
    AND n.shift_type = 'NIGHT'
WHERE f.shift_date = '2026-08-20'
  AND n.department_id IS NULL;

  -- method 3 
  SELECT department_id,SUM(
            CASE 
                WHEN shift_type = 'NIGHT' THEN 1
                ELSE 0
            END ) AS NIGHT_SHIFT_COUNT
  FROM factless_staff_coverage
  WHERE shift_date = '2026-08-20'
  GROUP BY department_id
  HAVING NIGHT_SHIFT_COUNT =0;


-- TASK 3: Patient Lifecycle Accumulating Snapshot Table
-- - Create `FACT_PATIENT_ADMISSION_LIFECYCLE` calculating:
CREATE TABLE FACT_PATIENT_ADMISSION_LIFECYCLE(
encounter_id STRING,
patient_id STRING,
triage_to_admit_days INT,
length_of_stay_days INT
);

INSERT INTO FACT_PATIENT_ADMISSION_LIFECYCLE 
SELECT $1,$2,
        TIMESTAMPDIFF('DAY',$3,NULLIF($4,'NULL')),
        TIMESTAMPDIFF('DAY',NULLIF($4,'NULL'),NULLIF($5,'NULL'))
FROM @project19b_stage/raw_patient_journey.csv
;
SELECT * 
FROM fact_patient_admission_lifecycle
WHERE length_of_stay_days IS NOT NULL;


-- TASK 4: Categorize Additive vs Non-Additive Billing Measures
CREATE TABLE FACT_TREATMENT_BILLING(
claim_id STRING,
encounter_id STRING,
procedure_cost NUMBER(10,2),
copay_amount NUMBER(10,2),
net_charge DECIMAL(10,2)
);

-- - Compute `NET_CHARGE` = `(procedure_cost * (1 - insurance_discount_pct)) - copay_amount`.
-- - Note: `insurance_discount_pct` is Non-Additive; `procedure_cost` and `NET_CHARGE` are Additive.
INSERT INTO fact_treatment_billing
SELECT $1,$2,$4,$6,ROUND($4 * (1 - $5) -$6,2)
FROM @project19b_stage/raw_treatment_bills.csv;

SELECT * 
FROM fact_treatment_billing;


-- TASK 5: Patient Billing Aggregation
-- - Query total net charges and average procedure cost per encounter.
SELECT encounter_id, SUM(net_charge) AS total_net_charges, ROUND(AVG(PROCEDURE_COST),2) AS AVG_PROCEDURE_COST
FROM fact_treatment_billing
GROUP BY encounter_id;


-- TASK 6: Audit Untreated / Non-Billed Encounters
-- - Identify encounters in `FACT_PATIENT_ADMISSION_LIFECYCLE` that generated ZERO claims in `FACT_TREATMENT_BILLING`.
SELECT p.ENCOUNTER_ID, PATIENT_ID , 'NO_CLAIMS_ISSUED' AS UNBILLED_STATUS  
FROM fact_patient_admission_lifecycle p 
LEFT JOIN FACT_TREATMENT_BILLING t
    ON p.encounter_id = t.encounter_id
WHERE t.claim_id IS NULL;

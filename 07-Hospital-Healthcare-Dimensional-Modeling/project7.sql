CREATE WAREHOUSE hospital_wh
WITH 
AUTO_SUSPEND = 60
WAREHOUSE_SIZE = "xsmall";
USE WAREHOUSE hospital_wh;

CREATE DATABASE hospital_db;
USE DATABASE hospital_db;

CREATE SCHEMA hospital_schema;
USE SCHEMA hospital_schema;

CREATE FILE FORMAT csv_format
TYPE = 'csv'
SKIP_HEADER = 1
FIELD_DELIMITER = ','
SKIP_BLANK_LINES = TRUE;

CREATE STAGE hospital_stage
FILE_FORMAT = csv_format ;

CREATE TABLE dim_patient(
patient_key INT PRIMARY KEY AUTOINCREMENT,
patient_id varchar(20) UNIQUE NOT NULL,
patient_name varchar(20),
gender varchar(20),
city varchar(20),
state varchar(20)
);

CREATE TABLE dim_doctors(
    doctor_key INT PRIMARY KEY AUTOINCREMENT,
    doctor_id VARCHAR(20) UNIQUE NOT NULL ,
    doctor_name VARCHAR(20),
    specialization VARCHAR(20)
);

CREATE TABLE dim_hospitals(
hospital_key INT PRIMARY KEY AUTOINCREMENT,
hospital_id VARCHAR(20) UNIQUE NOT NULL,
hospital_name VARCHAR(20),
city VARCHAR(20),
state VARCHAR(20),
region VARCHAR(20)
);

CREATE OR REPLACE TABLE dim_departments(
    department_key INT PRIMARY KEY AUTOINCREMENT,
    department_id VARCHAR(20) UNIQUE NOT NULL,
    department_name VARCHAR(20)
);

CREATE OR REPLACE TABLE dim_treatments(
    treatment_key INT PRIMARY KEY AUTOINCREMENT,
    treatment_id VARCHAR(20) UNIQUE NOT NULL,
    treatment_name VARCHAR(20),
    treatment_category VARCHAR(20)
);

CREATE OR REPLACE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE,
    day INT,
    day_name VARCHAR(20),
    week_no INT,
    month INT,
    month_name VARCHAR(20),
    quarter VARCHAR(5),
    year INT
);

CREATE TABLE fact_admissions (
    admission_key INT PRIMARY KEY AUTOINCREMENT,
    patient_key INT,
    doctor_key INT,
    hospital_key INT,
    department_key INT,
    date_key INT,
    admission_count INT,
    length_of_stay INT,

    FOREIGN KEY (patient_key)
        REFERENCES dim_patient(patient_key),

    FOREIGN KEY (doctor_key)
        REFERENCES dim_doctors(doctor_key),

    FOREIGN KEY (hospital_key)
        REFERENCES dim_hospitals(hospital_key),

    FOREIGN KEY (department_key)
        REFERENCES dim_departments(department_key),

    FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key)
);

CREATE TABLE fact_billing (
    billing_key INT PRIMARY KEY AUTOINCREMENT,
    patient_key INT,
    doctor_key INT,
    hospital_key INT,
    department_key INT,
    treatment_key INT,
    date_key INT,
    quantity INT,
    treatment_amount DECIMAL(10,2),
    discount DECIMAL(10,2),
    net_amount DECIMAL(10,2),

    FOREIGN KEY (patient_key)
        REFERENCES dim_patient(patient_key),

    FOREIGN KEY (doctor_key)
        REFERENCES dim_doctors(doctor_key),

    FOREIGN KEY (hospital_key)
        REFERENCES dim_hospitals(hospital_key),

    FOREIGN KEY (department_key)
        REFERENCES dim_departments(department_key),

    FOREIGN KEY (treatment_key)
        REFERENCES dim_treatments(treatment_key),

    FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key)
);




COPY INTO dim_patient (patient_id,patient_name,gender,city,state)
FROM @hospital_stage/patient.csv;

COPY INTO dim_doctors (doctor_id,doctor_name,specialization)
FROM @hospital_stage/doctor.csv;

COPY INTO dim_hospitals (hospital_id,hospital_name,city,state,region)
FROM @hospital_stage/hospitals.csv;


COPY INTO dim_departments (department_id,department_name)
FROM @hospital_stage/departments.csv;

COPY INTO dim_treatments (treatment_id,treatment_name,treatment_category)
FROM @hospital_stage/treatments.csv;


INSERT INTO dim_date
(date_key,full_date,day,day_name,week_no,month,month_name,quarter,year)
SELECT
    TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) AS date_key,
    full_date,
    DAY(full_date) AS day,
    DAYNAME(full_date) AS day_name,
    WEEKOFYEAR(full_date) AS week_no,
    MONTH(full_date) AS month,
    MONTHNAME(full_date) AS month_name,
    'Q' || QUARTER(full_date) AS quarter,
    YEAR(full_date) AS year
FROM (
    SELECT DATEADD(
        DAY,
        SEQ4(),
        '2026-01-01'::DATE
    ) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 90))
)
WHERE full_date <= '2026-03-31';



INSERT INTO fact_admissions
(patient_key,doctor_key,hospital_key,department_key,date_key,admission_count,length_of_stay)
SELECT
    p.patient_key,dr.doctor_key,h.hospital_key,d.department_key,dt.date_key,
    1 AS admission_count, DATEDIFF(DAY, a.$6::DATE, a.$7::DATE) AS length_of_stay
FROM @hospital_stage/admissions.csv a
JOIN dim_patient p
    ON p.patient_id = a.$2
JOIN dim_doctors dr
    ON dr.doctor_id = a.$3
JOIN dim_hospitals h
    ON h.hospital_id = a.$4
JOIN dim_departments d
    ON d.department_id = a.$5
JOIN dim_date dt
    ON dt.full_date = a.$6::DATE;

INSERT INTO fact_billing
(patient_key,doctor_key,hospital_key,department_key,treatment_key,date_key,quantity,treatment_amount,discount,net_amount)
SELECT
    p.patient_key,dr.doctor_key,h.hospital_key,d.department_key,t.treatment_key,dt.date_key,
    b.$8 , b.$9, b.$10, b.$11
FROM @hospital_stage/billing.csv b
JOIN dim_patient p
    ON p.patient_id = b.$2
JOIN dim_doctors dr
    ON dr.doctor_id = b.$3
JOIN dim_hospitals h
    ON h.hospital_id = b.$4
JOIN dim_departments d
    ON d.department_id = b.$5
JOIN dim_treatments t
    ON t.treatment_id = b.$6
JOIN dim_date dt
    ON dt.full_date = b.$7;



-- hospital wise total admissions
SELECT h.hospital_id,h.hospital_name,SUM(a.admission_count) AS total_admissions
FROM dim_hospitals h 
JOIN fact_admissions a 
    ON h.hospital_key = a.hospital_key
GROUP BY h.hospital_id,h.hospital_name
ORDER BY total_admissions DESC;


-- Hospital Revenue Analytics
SELECT h.hospital_id,h.hospital_name,SUM(b.net_amount) AS revenue
FROM dim_hospitals h 
JOIN fact_billing b 
    ON h.hospital_key = b.hospital_key
GROUP BY  h.hospital_id,h.hospital_name
ORDER BY revenue DESC;  


-- monthly hospitals revenue
SELECT d.month,d.month_name,h.hospital_id,h.hospital_name,SUM(b.net_amount) AS total
FROM dim_date d 
JOIN fact_billing b 
    ON d.date_key = b.date_key 
JOIN dim_hospitals h 
    ON b.hospital_key = h.hospital_key
GROUP BY d.month,d.month_name,h.hospital_id,h.hospital_name
ORDER BY d.month,total DESC;


-- Doctor-wise Revenue
SELECT d.doctor_id,d.doctor_name,SUM(b.net_amount) AS revenue
FROM dim_doctors d
JOIN fact_billing b 
    ON d.doctor_key = b.doctor_key
GROUP BY  d.doctor_id,d.doctor_name
ORDER BY revenue DESC;  


-- compare:Total Admissions and Total Revenue by Hospital
WITH total_revenue AS (
    SELECT h.hospital_id,h.hospital_name,SUM(b.net_amount) AS revenue
    FROM dim_hospitals h 
    JOIN fact_billing b 
        ON h.hospital_key = b.hospital_key
    GROUP BY  h.hospital_id,h.hospital_name
),
total_admissions AS 
(
    SELECT h.hospital_id,h.hospital_name,SUM(a.admission_count) AS admissions
    FROM dim_hospitals h 
    JOIN fact_admissions a 
        ON h.hospital_key = a.hospital_key
    GROUP BY h.hospital_id,h.hospital_name


)
SELECT h.hospital_id,h.hospital_name,t.revenue,a.admissions
FROM dim_hospitals h 
JOIN total_revenue t 
    ON h.hospital_id = t.hospital_id
JOIN total_admissions a 
    ON h.hospital_id = a.hospital_id    
ORDER BY a.admissions DESC;  



-- | Dimension      | FACT_ADMISSION | FACT_BILLING |
-- | -------------- | :------------: | :----------: |
-- | DIM_PATIENT    |        ✓       |       ✓      |
-- | DIM_DOCTOR     |        ✓       |       ✓      |
-- | DIM_HOSPITAL   |        ✓       |       ✓      |
-- | DIM_DEPARTMENT |        ✓       |       ✓      |
-- | DIM_DATE       |        ✓       |       ✓      |
-- | DIM_TREATMENT  |        —       |       ✓      |


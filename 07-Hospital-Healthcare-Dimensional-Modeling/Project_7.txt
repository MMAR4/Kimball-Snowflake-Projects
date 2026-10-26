1.Project Name: Hospital Healthcare Analytics using Snowflake Dimensional Modeling
----------------
2. Problem Statement
-----------------------
A hospital network operates multiple hospitals and wants to build a 
Data Warehouse in Snowflake for management analytics.

The hospital currently maintains operational data about:

Patients
Doctors
Hospitals
Departments
Treatments
Patient admissions
Medical billing

Management wants to analyze two major business processes:

Business Process 1 — Patient Admissions
------------------------------------------
Every time a patient is admitted to a hospital, an admission 
transaction is recorded.

Management wants to analyze:
----------------------
Number of admissions
Length of stay
Admissions by hospital
Admissions by department
Admissions by doctor
Monthly admissions

Business Process 2 — Medical Billing
------------------------------------
Whenever a patient receives a treatment, a billing transaction is 
generated.

Management wants to analyze:

Total treatment revenue
Revenue by hospital
Revenue by department
Revenue by doctor
Revenue by treatment
Monthly revenue

The hospital wants both business processes to use common dimensions 
so that management can compare admissions and revenue using the same 
hospital, doctor, department, patient, and date dimensions.

You are a Data Warehouse developer. Your task is to implement a Kimball dimensional model in Snowflake.

3. Learning Objectives
-------------------------
After completing this project, students should be able to:

Identify business processes.
Identify business events.
Design fact tables.
Design dimension tables.
Define the grain of a fact table.
Identify additive measures.
Create surrogate keys.
Create relationships between fact and dimension tables.
Identify conformed dimensions.
Perform drill-across analysis between two fact tables.

4. Input CSV Files
--------------------
Students will be provided with 6 CSV files.

patients.csv
------------
patient_id,patient_name,gender,city,state
P101,Amit Sharma,Male,Hyderabad,Telangana
P102,Priya Reddy,Female,Warangal,Telangana
P103,Rahul Verma,Male,Vijayawada,Andhra Pradesh
P104,Neha Patel,Female,Hyderabad,Telangana
P105,Arjun Gupta,Male,Nagpur,Maharashtra
P106,Sneha Rao,Female,Bengaluru,Karnataka

doctors.csv
-----------
doctor_id,doctor_name,specialization
D201,Dr. Rao,Cardiology
D202,Dr. Mehta,Neurology
D203,Dr. Kumar,Orthopedics
D204,Dr. Sharma,General Medicine

hospitals.csv
-------------
hospital_id,hospital_name,city,state,region
H301,KMIT Hospital,Hyderabad,Telangana,South
H302,City Care Hospital,Warangal,Telangana,South
H303,Apollo Care,Vijayawada,Andhra Pradesh,South

departments.csv
---------------
department_id,department_name
DP401,Cardiology
DP402,Neurology
DP403,Orthopedics
DP404,General Medicine

treatments.csv
--------------
treatment_id,treatment_name,treatment_category
T501,ECG,Diagnostic
T502,MRI Scan,Diagnostic
T503,X-Ray,Diagnostic
T504,Consultation,Consultation
T505,Physiotherapy,Therapy
T506,Blood Test,Diagnostic

admissions.csv
--------------
admission_id,patient_id,doctor_id,hospital_id,department_id,admission_date,discharge_date
A001,P101,D201,H301,DP401,2026-01-05,2026-01-08
A002,P102,D202,H302,DP402,2026-01-10,2026-01-15
A003,P103,D203,H303,DP403,2026-01-12,2026-01-18
A004,P104,D204,H301,DP404,2026-01-20,2026-01-22
A005,P105,D201,H301,DP401,2026-02-03,2026-02-07
A006,P106,D202,H302,DP402,2026-02-08,2026-02-12
A007,P101,D201,H301,DP401,2026-02-15,2026-02-20
A008,P102,D202,H302,DP402,2026-03-02,2026-03-06
A009,P103,D203,H303,DP403,2026-03-10,2026-03-16
A010,P104,D204,H301,DP404,2026-03-18,2026-03-20

billing.csv
-------------
admission_id,patient_id,doctor_id,hospital_id,department_id,admission_date,discharge_date
A001,P101,D201,H301,DP401,2026-01-05,2026-01-08
A002,P102,D202,H302,DP402,2026-01-10,2026-01-15
A003,P103,D203,H303,DP403,2026-01-12,2026-01-18
A004,P104,D204,H301,DP404,2026-01-20,2026-01-22
A005,P105,D201,H301,DP401,2026-02-03,2026-02-07
A006,P106,D202,H302,DP402,2026-02-08,2026-02-12
A007,P101,D201,H301,DP401,2026-02-15,2026-02-20
A008,P102,D202,H302,DP402,2026-03-02,2026-03-06
A009,P103,D203,H303,DP403,2026-03-10,2026-03-16
A010,P104,D204,H301,DP404,2026-03-18,2026-03-20

Actually, there are 7 files because admissions and billing are 
separate business processes.

TASK 1 — Create Snowflake Environment
-------

TASK 2 — Create Dimension Tables
-------
Create the following dimensions:

DIM_PATIENT
DIM_DOCTOR
DIM_HOSPITAL
DIM_DEPARTMENT
DIM_TREATMENT
DIM_DATE

Use surrogate keys in the dimensions.

TASK 3 — Load Dimension Data
------------------------------
Load the CSV data into the corresponding dimension tables.
Students should use Snowflake stages and COPY INTO.

For example:
-------------
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
TYPE = 'CSV'
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
SKIP_HEADER = 1;

Then create an internal stage:
--------------------------------
CREATE OR REPLACE STAGE HEALTHCARE_STAGE
FILE_FORMAT = CSV_FORMAT;

you should upload the CSV files to the stage and load them.

Expected Output:
-------------------
Patients Loaded: 6
Doctors Loaded: 4
Hospitals Loaded: 3
Departments Loaded: 4
Treatments Loaded: 6

TASK 4 — Create DIM_DATE
---------------------------
Create a date dimension covering: 2026-01-01 to 2026-03-31

The table should contain:
----------------------------
DATE_KEY
FULL_DATE
DAY
DAY_NAME
WEEK_NO
MONTH
MONTH_NAME
QUARTER
YEAR

Expected Sample Output:
------------------------
DATE_KEY   FULL_DATE    DAY   DAY_NAME   MONTH   QUARTER   YEAR
20260101   2026-01-01    1    Thursday      1       Q1      2026
20260102   2026-01-02    2    Friday        1       Q1      2026
...

TASK 5 — Identify the Business Processes
--------------------------------------------
Students must identify:
Business Process 1
Patient Admissions

Business Process 2
Medical Billing

Expected Output:
-----------------
Business Processes
-------------------
1. Patient Admissions
2. Medical Billing

TASK 6 — Create FACT_ADMISSION
-------------------------------
Structure
------------
| Column          | Type         |
| --------------- | ------------ |
| ADMISSION_KEY   | Surrogate PK |
| PATIENT_KEY     | FK           |
| DOCTOR_KEY      | FK           |
| HOSPITAL_KEY    | FK           |
| DEPARTMENT_KEY  | FK           |
| DATE_KEY        | FK           |
| ADMISSION_COUNT | Measure      |
| LENGTH_OF_STAY  | Measure      |

TASK 7 — Define FACT_ADMISSION Grain
------------------------------------
Students must explicitly define:
One record in FACT_ADMISSION represents one patient admission to one hospital, under one doctor and department, on one admission date.

Expected Output:
---------------
FACT_ADMISSION GRAIN

One record = One patient admission
to one hospital under one doctor
and department on one admission date.


TASK 8 — Create FACT_BILLING
--------------------------------
Structure
-----------
| Column           | Type         |
| ---------------- | ------------ |
| BILLING_KEY      | Surrogate PK |
| PATIENT_KEY      | FK           |
| DOCTOR_KEY       | FK           |
| HOSPITAL_KEY     | FK           |
| DEPARTMENT_KEY   | FK           |
| TREATMENT_KEY    | FK           |
| DATE_KEY         | FK           |
| QUANTITY         | Measure      |
| TREATMENT_AMOUNT | Measure      |
| DISCOUNT         | Measure      |
| NET_AMOUNT       | Measure      |

Calculate: NET_AMOUNT = TREATMENT_AMOUNT - DISCOUNT

TASK 9 — Define FACT_BILLING Grain
-----------------------------------
Students must define:One record in FACT_BILLING represents one treatment/service 
billed to one patient by one doctor at one hospital on one billing 
date.

TASK 10 — Identify Measures
-----------------------------
Students should identify:

FACT_ADMISSION
--------------
ADMISSION_COUNT
LENGTH_OF_STAY

FACT_BILLING
---------------
QUANTITY
TREATMENT_AMOUNT
DISCOUNT
NET_AMOUNT


Expected Output:
-----------------
Measures
----------------------------

FACT_ADMISSION
Admission_Count     Additive
Length_of_Stay      Additive

FACT_BILLING
Quantity            Additive
Treatment_Amount    Additive
Discount            Additive
Net_Amount          Additive


TASK 11 — Create Conformed Dimensions
--------------------------------------
Students must identify dimensions shared by both fact tables.

Expected Output:
----------------
Conformed Dimensions
--------------------
DIM_PATIENT
DIM_DOCTOR
DIM_HOSPITAL
DIM_DEPARTMENT
DIM_DATE

The treatment dimension is used only by FACT_BILLING.


TASK 12 — Build the Star Schema
--------------------------------
Students should produce the following model:
                    DIM_PATIENT
                         |
                         |
DIM_DOCTOR ------ FACT_ADMISSION ------ DIM_DATE
                         |
                    DIM_HOSPITAL
                         |
                   DIM_DEPARTMENT
and:

                    DIM_PATIENT
                         |
                         |
DIM_DOCTOR ------- FACT_BILLING ------- DIM_DATE
                         |
                    DIM_HOSPITAL
                         |
                   DIM_DEPARTMENT
                         |
                   DIM_TREATMENT

TASK 13 — Admission Analytics
-----------------------------
Generate the following report:

Exact Output:
---------------
HOSPITAL_NAME          TOTAL_ADMISSIONS
----------------------------------------
KMIT Hospital                  5
City Care Hospital             3
Apollo Care                    2


TASK 14 — Hospital Revenue Analytics
-------------------------------------
Calculate hospital-wise billing revenue.

Expected Output:
---------------
HOSPITAL_NAME          TOTAL_REVENUE
-------------------------------------
City Care Hospital          9900
KMIT Hospital               7400
Apollo Care                 5400


TASK 15 — Monthly Revenue
---------------------------
Generate monthly hospital revenue.

Expected Output
----------------
MONTH       TOTAL_REVENUE
-------------------------
2026-01          12250
2026-02           7000
2026-03           3450

TASK 16 — Doctor-wise Revenue
--------------------------------
Generate:
Doctor
Total Revenue

Expected Output:Using the supplied billing data:
----------------
DOCTOR        TOTAL_REVENUE
---------------------------
Dr. Rao           3700
Dr. Mehta         9900
Dr. Kumar         5400
Dr. Sharma        3050


TASK 17 — Drill-Across Analysis
---------------------------------
Management wants to compare:Total Admissions and Total Revenue by Hospital.

Students must combine the two fact tables through the conformed hospital dimension.

Expected Output
------------------
HOSPITAL_NAME          TOTAL_ADMISSIONS   TOTAL_REVENUE
-------------------------------------------------------
KMIT Hospital                 5               7400
City Care Hospital            3               9900
Apollo Care                   2               5400

This demonstrates the purpose of a conformed dimension: the same DIM_HOSPITAL can be used to analyze two different fact tables.

TASK 18 — Prepare Bus Matrix
-----------------------------
Students must create:

| Dimension      | FACT_ADMISSION | FACT_BILLING |
| -------------- | -------------: | -----------: |
| DIM_PATIENT    |              ✓ |            ✓ |
| DIM_DOCTOR     |              ✓ |            ✓ |
| DIM_HOSPITAL   |              ✓ |            ✓ |
| DIM_DEPARTMENT |              ✓ |            ✓ |
| DIM_DATE       |              ✓ |            ✓ |
| DIM_TREATMENT  |              — |            ✓ |

Expected Output
------------------
                 FACT_ADMISSION    FACT_BILLING

Patient                 ✓               ✓
Doctor                  ✓               ✓
Hospital                ✓               ✓
Department              ✓               ✓
Date                    ✓               ✓
Treatment               —               ✓
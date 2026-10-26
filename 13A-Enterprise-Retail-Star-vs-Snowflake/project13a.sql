-- TASK 1 — CREATE WAREHOUSE, DATABASE & SCHEMA
CREATE OR REPLACE WAREHOUSE project13_wh
WITH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60;

USE WAREHOUSE project13_wh;

CREATE OR REPLACE DATABASE retail_schemas_dw;
USE DATABASE retail_schemas_dw;

CREATE OR REPLACE SCHEMA schema_comparison;
USE SCHEMA schema_comparison;


SELECT CURRENT_DATABASE(), CURRENT_SCHEMA();


-- CREATE FILE FORMAT
CREATE OR REPLACE FILE FORMAT csv_format
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 2
SKIP_BLANK_LINES = TRUE;


-- CREATE STAGE
CREATE OR REPLACE STAGE retail_stage
FILE_FORMAT = csv_format;

LIST @retail_stage;
-- STAGING TABLE FOR SALES
CREATE OR REPLACE TABLE sales_stage_data (
    transaction_id VARCHAR(50),
    transaction_date DATE,
    customer_id NUMBER,
    store_id NUMBER,
    product_id NUMBER,
    quantity NUMBER,
    unit_price NUMBER(10,2)
);



-- LOAD SALES TRANSACTIONS INTO STAGING TABLE
COPY INTO sales_stage_data
FROM @retail_stage/sales.csv;


SELECT *
FROM sales_stage_data;



-- TASK 2 — STAR SCHEMA STORE DIMENSION
CREATE OR REPLACE TABLE star_dim_store (
    store_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1,
    store_id NUMBER NOT NULL,
    store_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    region_name VARCHAR(50),
    regional_manager VARCHAR(100)
);



-- TASK 3 — STAR SCHEMA PRODUCT DIMENSION
CREATE OR REPLACE TABLE star_dim_product (
    product_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1,
    product_id NUMBER NOT NULL,
    product_name VARCHAR(100),
    subcategory_name VARCHAR(50),
    category_name VARCHAR(50),
    unit_price NUMBER(10,2)
);



-- TASK 4 — LOAD STAR SCHEMA DIMENSIONS
COPY INTO star_dim_store
(
    store_id,
    store_name,
    city,
    state,
    region_name,
    regional_manager
)
FROM @retail_stage/region.csv;


COPY INTO star_dim_product
(
    product_id,
    product_name,
    subcategory_name,
    category_name,
    unit_price
)
FROM @retail_stage/products.csv;


-- Verify dimensions
SELECT *
FROM star_dim_store
ORDER BY store_key;


SELECT *
FROM star_dim_product
ORDER BY product_key;



-- TASK 4 — CREATE STAR FACT TABLE
CREATE OR REPLACE TABLE star_fact_sales (
    sales_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    transaction_id VARCHAR(50),
    transaction_date DATE,
    customer_id NUMBER,
    store_key NUMBER,
    product_key NUMBER,
    quantity NUMBER,
    unit_price NUMBER(10,2),

    FOREIGN KEY (store_key)
        REFERENCES star_dim_store(store_key),

    FOREIGN KEY (product_key)
        REFERENCES star_dim_product(product_key)
);



-- TASK 5 — LOAD STAR FACT TABLE
-- LOOK UP SURROGATE KEYS FROM DIMENSIONS
INSERT INTO star_fact_sales
(
    transaction_id,
    transaction_date,
    customer_id,
    store_key,
    product_key,
    quantity,
    unit_price
)
SELECT
    s.transaction_id,
    s.transaction_date,
    s.customer_id,
    ds.store_key,
    dp.product_key,
    s.quantity,
    s.unit_price
FROM sales_stage_data s
JOIN star_dim_store ds
    ON s.store_id = ds.store_id
JOIN star_dim_product dp
    ON s.product_id = dp.product_id;


-- Verify Star Fact
SELECT *
FROM star_fact_sales
ORDER BY sales_key;



-- TASK 6 — SNOWFLAKE SCHEMA STORE HIERARCHY
CREATE OR REPLACE TABLE snow_dim_region (
    region_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    region_name VARCHAR(50),
    regional_manager VARCHAR(100)
);


CREATE OR REPLACE TABLE snow_dim_store (
    store_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    store_id NUMBER NOT NULL,
    store_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    region_key NUMBER,

    FOREIGN KEY (region_key)
        REFERENCES snow_dim_region(region_key)
);



-- TASK 7 — SNOWFLAKE SCHEMA PRODUCT HIERARCHY
CREATE OR REPLACE TABLE snow_dim_category (
    category_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    category_name VARCHAR(50)
);


CREATE OR REPLACE TABLE snow_dim_subcategory (
    subcategory_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    subcategory_name VARCHAR(50),
    category_key NUMBER,

    FOREIGN KEY (category_key)
        REFERENCES snow_dim_category(category_key)
);


CREATE OR REPLACE TABLE snow_dim_product (
    product_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    product_id NUMBER NOT NULL,
    product_name VARCHAR(100),
    unit_price NUMBER(10,2),
    subcategory_key NUMBER,

    FOREIGN KEY (subcategory_key)
        REFERENCES snow_dim_subcategory(subcategory_key)
);



-- TASK 8 — POPULATE SNOWFLAKE SCHEMA

-- 8.1 Populate REGION
INSERT INTO snow_dim_region
(
    region_name,
    regional_manager
)
SELECT DISTINCT
    region_name,
    regional_manager
FROM star_dim_store;


-- Verify
SELECT *
FROM snow_dim_region
ORDER BY region_key;


-- 8.2 Populate STORE
INSERT INTO snow_dim_store
(
    store_id,
    store_name,
    city,
    state,
    region_key
)
SELECT DISTINCT
    s.store_id,
    s.store_name,
    s.city,
    s.state,
    r.region_key
FROM star_dim_store s
JOIN snow_dim_region r
    ON s.region_name = r.region_name;


-- Verify
SELECT *
FROM snow_dim_store
ORDER BY store_key;



-- 8.3 Populate CATEGORY
INSERT INTO snow_dim_category
(
    category_name
)
SELECT DISTINCT
    category_name
FROM star_dim_product;


-- Verify
SELECT *
FROM snow_dim_category
ORDER BY category_key;



-- 8.4 Populate SUBCATEGORY
INSERT INTO snow_dim_subcategory
(
    subcategory_name,
    category_key
)
SELECT DISTINCT
    p.subcategory_name,
    c.category_key
FROM star_dim_product p
JOIN snow_dim_category c
    ON p.category_name = c.category_name;


-- Verify
SELECT *
FROM snow_dim_subcategory
ORDER BY subcategory_key;



-- 8.5 Populate PRODUCT
INSERT INTO snow_dim_product
(
    product_id,
    product_name,
    unit_price,
    subcategory_key
)
SELECT
    p.product_id,
    p.product_name,
    p.unit_price,
    sc.subcategory_key
FROM star_dim_product p
JOIN snow_dim_category c
    ON p.category_name = c.category_name
JOIN snow_dim_subcategory sc
    ON p.subcategory_name = sc.subcategory_name
   AND sc.category_key = c.category_key;


-- Verify
SELECT *
FROM snow_dim_product
ORDER BY product_key;



-- TASK 9 — CREATE SNOWFLAKE FACT TABLE
CREATE OR REPLACE TABLE snow_fact_sales (
    sales_key NUMBER PRIMARY KEY AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    transaction_id VARCHAR(50) NOT NULL,
    transaction_date DATE,
    customer_id NUMBER,
    store_key NUMBER,
    product_key NUMBER,
    quantity NUMBER,
    unit_price NUMBER(10,2),

    FOREIGN KEY (store_key)
        REFERENCES snow_dim_store(store_key),

    FOREIGN KEY (product_key)
        REFERENCES snow_dim_product(product_key)
);



-- TASK 9 — LOAD SNOWFLAKE FACT TABLE
-- IMPORTANT:
-- USE SNOWFLAKE DIMENSION SURROGATE KEYS
INSERT INTO snow_fact_sales
(
    transaction_id,
    transaction_date,
    customer_id,
    store_key,
    product_key,
    quantity,
    unit_price
)
SELECT
    t.transaction_id,
    t.transaction_date,
    t.customer_id,
    s.store_key,
    p.product_key,
    t.quantity,
    t.unit_price
FROM sales_stage_data t
JOIN snow_dim_store s
    ON t.store_id = s.store_id
JOIN snow_dim_product p
    ON t.product_id = p.product_id;


-- Verify
SELECT *
FROM snow_fact_sales
ORDER BY sales_key;



-- TASK 10 — STAR SCHEMA ANALYTICS
-- REGION + CATEGORY REVENUE
SELECT
    s.region_name,
    p.category_name,
    SUM(fs.quantity * fs.unit_price) AS total_revenue
FROM star_fact_sales fs
JOIN star_dim_store s
    ON fs.store_key = s.store_key
JOIN star_dim_product p
    ON fs.product_key = p.product_key
GROUP BY
    s.region_name,
    p.category_name
ORDER BY
    s.region_name,
    p.category_name;



-- TASK 11 — SNOWFLAKE SCHEMA ANALYTICS
-- MULTI-HOP JOIN
SELECT
    r.region_name,
    c.category_name,
    SUM(fs.quantity * fs.unit_price) AS total_revenue
FROM snow_fact_sales fs

JOIN snow_dim_store s
    ON fs.store_key = s.store_key

JOIN snow_dim_region r
    ON s.region_key = r.region_key

JOIN snow_dim_product p
    ON fs.product_key = p.product_key

JOIN snow_dim_subcategory sc
    ON p.subcategory_key = sc.subcategory_key

JOIN snow_dim_category c
    ON sc.category_key = c.category_key

GROUP BY
    r.region_name,
    c.category_name

ORDER BY
    r.region_name,
    c.category_name;



-- TASK 12 — STAR vs SNOWFLAKE ARCHITECTURAL COMPARISON
SELECT
    'Dimension Normalization Level' AS metric,
    'Denormalized (Flat)' AS star_schema,
    'Normalized (Hierarchical)' AS snowflake_schema

UNION ALL

SELECT
    'Total Dimension Tables',
    '2 Tables',
    '5 Tables'

UNION ALL

SELECT
    'Joins for Category Revenue',
    '2 Joins',
    '5 Joins'

UNION ALL

SELECT
    'Data Redundancy',
    'Higher',
    'Lower'

UNION ALL

SELECT
    'Query Simplicity',
    'High',
    'Lower';



-- TASK 13 — REGIONAL MANAGER SALES PERFORMANCE


SELECT
    s.regional_manager,
    SUM(fs.quantity) AS total_items_sold,
    SUM(fs.quantity * fs.unit_price) AS total_sales_amount
FROM star_fact_sales fs
JOIN star_dim_store s
    ON fs.store_key = s.store_key
GROUP BY
    s.regional_manager
ORDER BY
    s.regional_manager;



-- TASK 14 — FULL WAREHOUSE ARCHITECTURE AUDIT
SELECT
    'Star Schema' AS schema_type,
    'STAR_DIM_STORE' AS table_name,
    COUNT(*) AS record_count
FROM star_dim_store

UNION ALL

SELECT
    'Star Schema',
    'STAR_DIM_PRODUCT',
    COUNT(*)
FROM star_dim_product

UNION ALL

SELECT
    'Star Schema',
    'STAR_FACT_SALES',
    COUNT(*)
FROM star_fact_sales

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_REGION',
    COUNT(*)
FROM snow_dim_region

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_STORE',
    COUNT(*)
FROM snow_dim_store

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_CATEGORY',
    COUNT(*)
FROM snow_dim_category

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_SUBCATEGORY',
    COUNT(*)
FROM snow_dim_subcategory

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_PRODUCT',
    COUNT(*)
FROM snow_dim_product

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_FACT_SALES',
    COUNT(*)
FROM snow_fact_sales

ORDER BY
    schema_type,
    table_name;

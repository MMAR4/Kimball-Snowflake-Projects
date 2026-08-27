CREATE OR REPLACE WAREHOUSE sales2_wh
WITH 
WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND=60;

USE WAREHOUSE sales2_wh;

CREATE DATABASE sales2_db;
USE DATABASE sales2_db;

CREATE SCHEMA sales_schema;
USE SCHEMA sales_schema;

CREATE FILE FORMAT csv_format
TYPE = 'csv'
Field_delimiter = ','
skip_header = 1
skip_blank_lines = TRUE ;

CREATE STAGE sales_stage
FILE_FORMAT = csv_format;
LIST @sales_stage;

CREATE TABLE dim_customers(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(50),
city VARCHAR(50),
state VARCHAR(50),
membership VARCHAR(15)
);

CREATE TABLE dim_products(
product_id INT PRIMARY KEY,
product_name VARCHAR(50),
category VARCHAR(50),
brand VARCHAR(30),
price DECIMAL(10,2)
);

CREATE TABLE dim_branches (
branch_id INT PRIMARY KEY,
branch_name VARCHAR(50),
city VARCHAR(50),
state VARCHAR(50),
region VARCHAR(50),
manager_name VARCHAR(50)
);

CREATE OR REPLACE TABLE dim_date(
date_id INT PRIMARY KEY,
date DATE,
day INT,
day_name VARCHAR(10),
week_no INT,
month VARCHAR(10),
quarter VARCHAR(5),
year INT,
is_weekend BOOLEAN
);

CREATE TABLE fact_sales(
sale_id INT PRIMARY KEY,
customer_id INT REFERENCES dim_customers(customer_id),
product_id INT REFERENCES dim_products(product_id),
branch_id INT REFERENCES dim_branches(branch_id),
date_id INT REFERENCES dim_date(date_id),
quantity INT,
total_amount DECIMAL(10,2)
);
-- method1
COPY INTO dim_customers
FROM @sales_stage/customers.csv;

-- method 2
COPY INTO dim_products
FROM @sales_stage
FILES = ('products.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

COPY INTO dim_branches 
FROM @sales_stage/branches.csv;

COPY INTO dim_date
FROM @sales_stage
FILES = ('calendar.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

COPY INTO fact_sales
FROM @sales_stage/sales.csv;

-- ========================================================================
-- Customer-wise Sales Report
SELECT c.customer_id,c.customer_name,SUM(total_amount) AS revenue
FROM dim_customers c 
JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name
ORDER BY revenue DESC;


-- Product-wise Revenue Report
SELECT p.product_id,p.product_name,SUM(total_amount) AS revenue
FROM dim_products p
JOIN fact_sales s 
    ON  p.product_id = s.product_id
GROUP BY p.product_id,p.product_name
ORDER BY revenue DESC;


-- Branch-wise Revenue Report

SELECT b.branch_id,b.branch_name,SUM(total_amount) AS revenue
FROM dim_branches b
JOIN fact_sales s 
    ON  b.branch_id = s.branch_id
GROUP BY b.branch_id,b.branch_name
ORDER BY revenue DESC;


-- State-wise Revenue Report
SELECT b.state,SUM(total_amount) AS revenue
FROM dim_branches b
JOIN fact_sales s 
    ON  b.branch_id = s.branch_id
GROUP BY b.state
ORDER BY revenue DESC;

-- Monthly Revenue Report
SELECT d.month,SUM(total_amount) AS revenue
FROM dim_date d
JOIN fact_sales s 
    ON  d.date_id= s.date_id
GROUP BY d.month
ORDER BY revenue DESC;

-- Quarterly Revenue Report
SELECT d.quarter,SUM(total_amount) AS revenue
FROM dim_date d
JOIN fact_sales s 
    ON  d.date_id = s.date_id
GROUP BY d.quarter
ORDER BY revenue DESC;


-- Top 10 Customers
SELECT *
FROM (
    SELECT c.customer_id,c.customer_name,
            SUM(s.total_amount) AS revenue,
            RANK() OVER(ORDER BY revenue DESC) AS rnk
    FROM dim_customers c 
    JOIN fact_sales s 
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_id,c.customer_name
)t
WHERE rnk <=10;


-- Top 10 Products
SELECT * 
FROM 
    (
    SELECT p.product_id,p.product_name,
            SUM(total_amount) AS revenue,
            ROW_NUMBER() OVER(ORDER BY revenue DESC) AS rnk
    FROM dim_products p 
    JOIN fact_sales s 
        ON p.product_id = s.product_id
    GROUP BY p.product_id,p.product_name
    )t
WHERE rnk <=10;


-- Top 10 Performing Branches

SELECT * 
FROM 
    (
    SELECT b.branch_id,b.branch_name,
            SUM(total_amount) AS revenue,
            RANK() OVER(ORDER BY revenue DESC) AS rnk
    FROM dim_branches b
    JOIN fact_sales s 
        ON b.branch_id = s.branch_id
    GROUP BY b.branch_id,b.branch_name
    )t
WHERE rnk <=10;

-- Category-wise Revenue
SELECT p.category,SUM(total_amount) AS revenue
FROM dim_products p
JOIN fact_sales s 
    ON p.product_id = s.product_id
GROUP BY p.category
ORDER BY revenue DESC;

CREATE WAREHOUSE transaction_wh
WAREHOUSE_SIZE = "XSMALL"
AUTO_SUSPEND = 60;

USE WAREHOUSE transaction_wh;

CREATE DATABASE transaction_db;
USE DATABASE transaction_db;

CREATE SCHEMA transaction_schema;
USE SCHEMA transaction_schema;

CREATE OR REPLACE FILE FORMAT csv_format
TYPE = 'csv'
FIELD_DELIMITER = ','
SKIP_HEADER= 1
SKIP_BLANK_LINES = TRUE;
DESC FILE FORMAT csv_format;

CREATE STAGE transaction_stage
FILE_FORMAT = csv_format;

LIST @transaction_stage;

CREATE TABLE dim_customers(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(50),
city VARCHAR(50),
state VARCHAR(50),
membership VARCHAR(50)
);

CREATE TABLE dim_products (
product_id INT PRIMARY KEY,
product_name VARCHAR(50),
category VARCHAR(50),
brand VARCHAR(50),
price DECIMAL(10,2)
);

CREATE TABLE dim_branches(
branch_id INT PRIMARY KEY,
branch_name VARCHAR(50),
city VARCHAR(50),
state VARCHAR(50),
region VARCHAR(50),
manager_name VARCHAR(50)
);

CREATE TABLE dim_calendar(
date_id INT PRIMARY KEY,
date DATE,
day INT,
day_name VARCHAR(10),
week_no INT,
month VARCHAR(10),
quarter VARCHAR(10),
year INT,
is_weekend VARCHAR(4)
);

CREATE OR REPLACE TABLE fact_sales(
sale_id INT PRIMARY KEY,
customer_id INT,
product_id INT,
branch_id INT,
date_id INT,
quantity INT,
total_amount DECIMAL(10,2),

FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
FOREIGN KEY (product_id) REFERENCES dim_products(product_id),
FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id),
FOREIGN KEY (date_id) REFERENCES dim_calendar(date_id)
);

COPY INTO dim_customers
FROM @transaction_stage/customers.csv;

COPY INTO dim_products
FROM @transaction_stage/products.csv;

COPY INTO dim_branches
FROM @transaction_stage/branches.csv;

COPY INTO dim_calendar
FROM @transaction_stage/calendar.csv;

COPY INTO fact_sales
FROM @transaction_stage/sales.csv;

SELECT * FROM dim_customers;

-- Customer-wise Sales Report
SELECT c.customer_id,c.customer_name, SUM(total_amount) AS revenue
FROM dim_customers c
LEFT JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name
ORDER BY revenue DESC;


-- Product-wise Revenue Report
SELECT p.product_id,p.product_name, SUM(s.total_amount) AS revenue
FROM dim_products p
LEFT JOIN fact_sales s 
    ON p.product_id = s.product_id
GROUP BY p.product_id,p.product_name
ORDER BY revenue DESC;

-- Branch-wise Sales Report
SELECT b.branch_id,b.branch_name,SUM(s.total_amount) AS revenue
FROM dim_branches b
LEFT JOIN fact_sales s 
    ON b.branch_id = s.branch_id
GROUP BY b.branch_id,b.branch_name
ORDER BY revenue DESC;

-- Monthly Revenue Report
SELECT c.MONTH,SUM(total_amount) AS revenue
FROM dim_calendar c 
JOIN fact_sales s 
    ON c.date_id = s.date_id
GROUP BY c.MONTH
ORDER BY revenue DESC;

-- State-wise Revenue Report
SELECT state,SUM(total_amount) AS revenue
FROM dim_branches b 
JOIN fact_sales s
    ON b.branch_id = s.branch_id
GROUP BY state 
ORDER BY revenue DESC;

-- Category-wise Revenue Report
SELECT p.category,SUM(total_amount) AS revenue
FROM dim_products p
JOIN fact_sales s
    ON p.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- Top 10 Customers based on Total Sales
SELECT customer_id,customer_name,spending
FROM (
    SELECT c.customer_id,customer_name,SUM(total_amount) AS spending,RANK() OVER(ORDER BY spending DESC) AS rnk
    FROM dim_customers c 
    JOIN fact_sales s 
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_id,customer_name
)t
WHERE rnk <= 10
;

-- Top 10 Products based on Revenue
SELECT product_id,product_name,revenue,rnk 
FROM(
    SELECT p.product_id,p.product_name,SUM(s.total_amount) AS revenue,
        DENSE_RANK() OVER(ORDER BY revenue DESC) AS rnk
    FROM dim_products p 
    JOIN fact_sales s 
        ON p.product_id = s.product_id
    GROUP BY p.product_id,p.product_name
    ) t
WHERE rnk <= 10
;


-- Top 10 Performing Branches
SELECT branch_id,branch_name, revenue, rnk
FROM(
    SELECT b.branch_id,branch_name,
            SUM(total_amount) AS revenue,
            DENSE_RANK() OVER(ORDER BY revenue DESC) AS rnk
    FROM dim_branches b 
    JOIN fact_sales s 
        ON b.branch_id = s.branch_id
    GROUP BY b.branch_id,branch_name
)t 
WHERE rnk <=10;



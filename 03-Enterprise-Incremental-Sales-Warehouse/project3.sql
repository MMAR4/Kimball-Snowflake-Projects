CREATE OR REPLACE WAREHOUSE ENTERPRISE_WH
WITH 
WAREHOUSE_SIZE = "XSMALL"
AUTO_SUSPEND=60;

USE WAREHOUSE ENTERPRISE_WH;

CREATE DATABASE ENTERPRISE_DB;
USE DATABASE ENTERPRISE_DB;

CREATE SCHEMA SALES_SCHEMA;
USE SCHEMA SALES_SCHEMA;

CREATE FILE FORMAT csv_format
TYPE = 'csv'
FIELD_DELIMITER = ','
SKIP_HEADER=1
SKIP_BLANK_LINES = TRUE;

CREATE STAGE sales_stage;
LIST @sales_stage;

CREATE TABLE dim_branches(
branch_id INT PRIMARY KEY,
branch_name VARCHAR(50),
state VARCHAR(50)
);

CREATE TABLE dim_customers(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(50),
city VARCHAR(50),
membership STRING
);

CREATE TABLE dim_products(
product_id INT PRIMARY KEY,
product_name VARCHAR(50),
category VARCHAR(50),
price NUMBER(10,2)
);


CREATE TABLE fact_sales(
sale_id INT PRIMARY KEY,
customer_id INT,
product_id INT,
branch_id INT,
quantity INT,
sale_date DATE,
total_amount NUMBER(10,2), 

FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
FOREIGN KEY (product_id) REFERENCES dim_products(product_id),
FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id)
);

CREATE OR REPLACE TABLE fact_new_sales(
sale_id INT PRIMARY KEY,
customer_id INT REFERENCES dim_customers(customer_id),
product_id INT REFERENCES dim_products(product_id),
branch_id INT REFERENCES dim_branches(branch_id),
quantity INT,
sale_date DATE,
total_amount NUMBER(10,2) 
);



COPY INTO dim_customers
FROM @sales_stage
FILES = ('customers.csv')
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');

COPY INTO dim_products
FROM @sales_stage
FILES = ('products.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

COPY INTO dim_branches
FROM @sales_stage
FILES = ('branches.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

COPY INTO fact_sales
FROM @sales_stage
FILES = ('sales_history.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

-- 10.Create a Stream on the SALES table.
CREATE STREAM sales_stream
ON TABLE fact_sales;

SHOW STREAMS;

SELECT * FROM sales_stream;

-- 11.Load new_sales.csv.
COPY INTO fact_new_sales
FROM @sales_stage
FILES = ('new_sales.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');


SELECT * FROM dim_customers;
SELECT * FROM dim_products;
SELECT * FROM dim_branches;
SELECT * FROM fact_new_sales;
SELECT * FROM fact_sales;


-- 12.Display only newly inserted records using the Stream.
-- 13.Merge newly arrived records into the SALES table.
MERGE INTO fact_sales t
USING fact_new_sales s 
    ON t.sale_id = s.sale_id

        
WHEN NOT MATCHED THEN
INSERT (sale_id,customer_id,product_id,branch_id,quantity,sale_date,total_amount) 
VALUES(s.sale_id,s.customer_id,s.product_id,s.branch_id,s.quantity,s.sale_date,s.total_amount);

SELECT * FROM fact_sales;
SELECT * FROM sales_stream;

-- 14.Identify duplicate Sale IDs.
SELECT sale_id,COUNT(*)
FROM fact_sales
GROUP BY sale_id
HAVING COUNT(*)>1;


-- 15.Identify missing Customer IDs.
SELECT s.* 
FROM dim_customers c
LEFT JOIN fact_sales s
    ON c.customer_id = s.customer_id
WHERE s.customer_id IS NULL;

-- 16.Display invalid Product IDs.
SELECT s.* 
FROM fact_sales s 
LEFT JOIN dim_products p 
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 17.Count total newly inserted records.
SELECT COUNT(*) AS cnt FROM sales_stream;


-- 18.Delete one sales record.
SELECT * FROM fact_sales;
DELETE FROM  fact_sales
WHERE sale_id = 3;

SELECT * FROM sales_stream;

-- Show fact_sales as it existed 5 minutes ago.
SELECT * 
FROM fact_sales
BEFORE(OFFSET =>-60*5);

-- 19.Recover the deleted record using Time Travel.
INSERT INTO fact_sales 
SELECT * 
FROM fact_sales 
BEFORE(OFFSET =>-60*5)
WHERE sale_id = 3;

-- 20.Verify recovery.
SELECT * FROM fact_sales;


-- 21.Create a clone named: SALES_TEST
CREATE TABLE SALES_TEST
CLONE fact_sales;

-- 22.Display cloned records.
SELECT * FROM sales_test;

-- 23.Insert one new record into the clone.
INSERT INTO sales_test VALUES(11,4,102,2,4,'2026-07-10',40000);

-- 24.Verify that the original SALES table remains unchanged.
SELECT * FROM fact_sales;

SHOW STREAMS;
-- 25.Create a Task that automatically performs incremental loading every day.
CREATE OR REPLACE STREAM sales_stream
    ON TABLE fact_new_sales;

CREATE OR REPLACE TASK auto_increment_load
WAREHOUSE = ENTERPRISE_WH
SCHEDULE = 'USING CRON 0 0 * * * UTC'
AS
MERGE INTO fact_sales t 
USING sales_stream AS s 
    ON t.sale_id = s.sale_id
    
WHEN NOT MATCHED THEN
INSERT (sale_id,customer_id,product_id,branch_id,quantity,sale_date,total_amount)
VALUES(s.sale_id,s.customer_id,s.product_id,s.branch_id,s.quantity,s.sale_date,s.total_amount);

-- 26.Resume the Task.
ALTER TASK auto_increment_load RESUME;

-- 27.Verify Task execution.
SHOW TASKS;


-- Generate
-- 28.Customer Revenue Report
SELECT c.customer_id,c.customer_name,SUM(s.total_amount) AS revenue 
FROM dim_customers c 
LEFT JOIN fact_sales s  
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name
ORDER BY revenue DESC;

-- 29.Branch Revenue Report
SELECT b.branch_id,b.branch_name,SUM(s.total_amount) AS revenue 
FROM dim_branches b 
LEFT JOIN fact_sales s  
    ON b.branch_id = b.branch_id
GROUP BY b.branch_id,b.branch_name
ORDER BY revenue DESC;

-- 30.Product Revenue Report
SELECT p.product_id,p.product_name,SUM(s.total_amount) AS revenue 
FROM dim_products p 
LEFT JOIN fact_sales s  
    ON s.product_id = p.product_id
GROUP BY p.product_id,p.product_name
ORDER BY revenue DESC;

-- 31.Monthly Revenue Report
SELECT MONTH(sale_date),SUM(total_amount) AS revenue 
FROM fact_sales
GROUP BY MONTH(sale_date)
ORDER BY revenue DESC;

-- 32.Highest Revenue Customer
-- using sub query
WITH revenue_cte AS(
SELECT c.customer_id, c.customer_name,SUM(total_amount) AS revenue
FROM dim_customers c
JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.customer_name)
SELECT * FROM revenue_cte
WHERE revenue=(SELECT MAX(revenue) FROM revenue_cte);

-- using window function
WITH cte AS (
SELECT c.customer_id, c.customer_name,SUM(total_amount) AS revenue
FROM dim_customers c
JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.customer_name),
cte2 AS
(SELECT customer_id, customer_name, revenue,RANK() OVER(ORDER BY revenue DESC) AS rnk
FROM cte )
SELECT * 
FROM cte2
WHERE rnk =1;



-- 33.Highest Revenue Branch
WITH revenue_cte AS 
(
    SELECT b.branch_id,b.branch_name,b.state,
        SUM(total_amount) AS revenue,
        RANK() OVER(ORDER BY revenue DESC) AS rnk
    FROM dim_branches b 
    JOIN fact_sales s 
        ON b.branch_id = s.branch_id
    GROUP BY b.branch_id,b.branch_name,b.state
)
SELECT * 
FROM revenue_cte
WHERE rnk = 1
;

-- 34.Top Five Products
WITH total_cte AS 
(
    SELECT p.product_id,p.product_name,
        SUM(total_amount) AS total,
        DENSE_RANK() OVER(ORDER BY total DESC) AS rnk
    FROM dim_products p
    JOIN fact_sales s 
        ON p.product_id = s.product_id
    GROUP BY p.product_id,p.product_name
)
SELECT * 
FROM total_cte 
WHERE rnk <=5;

-- 35.Customer Purchase Frequency
SELECT c.customer_id,c.customer_name,COUNT(s.customer_id) AS frequency  
FROM dim_customers c
JOIN fact_sales s  
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name
ORDER BY frequency DESC;

-- 36.Running Revenue
SELECT  sale_id,sale_date, total_amount,
        SUM(total_amount) OVER(ORDER BY sale_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) 
FROM fact_sales;


-- 37.Customer Ranking
SELECT c.customer_id,c.customer_name, SUM(s.total_amount) AS total, DENSE_RANK() OVER(ORDER BY total DESC)
FROM dim_customers c 
JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name;


-- 38.Create View: CUSTOMER_REVENUE
CREATE VIEW CUSTOMER_REVENUE AS 
SELECT c.customer_id,c.customer_name,SUM(total_amount) AS total
FROM dim_customers c 
JOIN fact_sales s 
ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name
ORDER BY total DESC;

SELECT * FROM CUSTOMER_REVENUE;


-- 39.Create Materialized View: BRANCH_REVENUE
CREATE MATERIALIZED VIEW BRANCH_REVENUE AS 
SELECT branch_id,SUM(total_amount) AS total
FROM fact_sales
GROUP BY branch_id;

SELECT * FROM BRANCH_REVENUE;


-- 40.Display data from both Views.

SELECT * FROM CUSTOMER_REVENUE;
SELECT * FROM BRANCH_REVENUE;

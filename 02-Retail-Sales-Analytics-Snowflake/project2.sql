CREATE WAREHOUSE RETAIL_WH
WITH
WAREHOUSE_SIZE="XSMALL"
AUTO_SUSPEND=60;

USE WAREHOUSE RETAIL_WH;

CREATE DATABASE RETAIL_DB;
USE DATABASE RETAIL_DB;

CREATE SCHEMA SALES_SCHEMA;
USE SCHEMA SALES_SCHEMA;

CREATE FILE FORMAT CSV_FORMAT
TYPE = 'csv'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
SKIP_BLANK_LINES = TRUE;

CREATE STAGE SALES_STAGE;
LIST @SALES_STAGE;

CREATE TABLE dim_customers(
customer_id INT PRIMARY KEY,
customer_name varchar(50),
city varchar(50),
membership varchar(15)
);

CREATE TABLE dim_products(
product_id INT PRIMARY KEY,
product_name VARCHAR(50),
category VARCHAR(50),
price INT
);

CREATE TABLE dim_branches(
branch_id INT PRIMARY KEY,
branch_name VARCHAR(50),
city VARCHAR(50)
);

CREATE TABLE fact_sales(
sale_id INT PRIMARY KEY,
customer_id INT NOT NULL,
product_id INT NOT NULL,
branch_id INT NOT NULL,
quantity INT,
sale_date DATE,
total_amount INT,
FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
FOREIGN KEY (product_id) REFERENCES dim_products(product_id),
FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id)
);

COPY INTO dim_customers
FROM @sales_stage
FILES = ('customers.csv')
file_format = (format_name='csv_format');

COPY INTO dim_products
FROM @sales_stage
FILES = ('products.csv')
FILE_FORMAT = (format_name = 'csv_format');

COPY INTO dim_branches 
FROM @sales_stage
FILES = ('branches.csv')
file_format = (format_name='csv_format');

COPY INTO fact_sales
FROM @sales_stage
FILES =('sales.csv')
file_format = (format_name = 'csv_format');



select * from dim_customers;
select * from dim_branches;
select * from dim_products;
select * from fact_sales;

-- Calculate total business revenue
SELECT SUM(total_amount) AS total_revenue
FROM fact_sales;

-- Generate customer-wise sales
SELECT c.customer_id,c.customer_name,SUM(s.total_amount) AS total_revenue
FROM dim_customers c
JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name
ORDER BY customer_id;


-- Generate branch-wise sales
SELECT b.branch_id,b.branch_name,SUM(s.total_amount) AS total_revenue
FROM dim_branches b
JOIN fact_sales s 
    ON b.branch_id = s.branch_id
GROUP BY b.branch_id,b.branch_name
ORDER BY b.branch_id;


-- Generate product-wise sales
SELECT p.product_id,p.product_name,SUM(s.total_amount) AS total_revenue
FROM dim_products p
JOIN fact_sales s 
    ON p.product_id = s.product_id
GROUP BY p.product_id,p.product_name
ORDER BY p.product_id;


-- Generate category-wise sales
SELECT p.category,SUM(s.total_amount) AS total_revenue
FROM dim_products p
JOIN fact_sales s 
    ON p.product_id = s.product_id
GROUP BY p.category
ORDER BY SUM(s.total_amount) desc;


-- Display the highest revenue branch.
SELECT b.branch_id,b.branch_name,b.city,SUM(s.total_amount) AS total_revenue
FROM dim_branches b
JOIN fact_sales s
    ON b.branch_id =s.branch_id
GROUP BY b.branch_id,b.branch_name,b.city
HAVING SUM(s.total_amount) =
   ( 
    SELECT MAX(total) 
    FROM 
        (
            SELECT SUM(total_amount) AS total
            FROM fact_sales s2 
            GROUP BY branch_id
        )t1
    );

-- Display the highest spending customer.
SELECT c.customer_id,c.customer_name,c.city,SUM(s.total_amount)  AS total_revenue
FROM dim_customers c 
JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name,c.city
HAVING SUM(s.total_amount) = 
    (
     SELECT MAX(total)
     FROM 
        (
         SELECT SUM(s2.total_amount) AS total
         FROM fact_sales s2 
         GROUP BY customer_id
        )t1
    );

-- without subquery using LIMIT 1 but if 2 or more customers have highesht revenue equal, limit should be change explicitly 
-- SELECT c.customer_id,c.customer_name,c.city,SUM(s.total_amount) 
-- FROM dim_customers c 
-- JOIN fact_sales s 
--     ON c.customer_id = s.customer_id
-- GROUP BY c.customer_id,c.customer_name,c.city
-- ORDER BY SUM(s.total_amount) DESC LIMIT 1;


-- Display the top three products by revenue.
SELECT p.product_id,p.product_name,SUM(s.total_Amount) AS total_revenue
FROM dim_products p 
JOIN fact_sales s
    ON p.product_id = s.product_id
GROUP BY p.product_id,p.product_name
ORDER BY total_revenue DESC 
LIMIT 3;


-- Display the top three customers by spending.

SELECT c.customer_id,c.customer_name,SUM(s.total_Amount) AS total_revenue
FROM dim_customers c 
JOIN fact_sales s
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name
ORDER BY total_revenue DESC 
LIMIT 3;



-- Rank customers based on total spending.
SELECT
    c.customer_id,
    c.customer_name,
    SUM(total_amount) AS "total spending",
    RANK() OVER(ORDER BY "total spending" DESC) AS rnk
    
FROM dim_customers c 
JOIN fact_sales s
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,c.customer_name;

-- Rank branches based on total sales.
SELECT 
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS "total sales",
    RANK() OVER(ORDER BY "total sales" DESC) AS rnk 
FROM dim_branches b
JOIN fact_sales s 
    ON b.branch_id = s.branch_id
GROUP BY b.branch_id,b.branch_name;



-- Display the top-selling product in each category using ROW_NUMBER().
WITH cte AS 
(
    SELECT 
    p.product_id,
    p.product_name,
    p.category,
    SUM(s.total_amount) AS total,
    ROW_NUMBER() OVER(PARTITION BY p.category ORDER BY total DESC) AS rnk
    
    FROM dim_products p
    JOIN fact_sales s 
        ON p.product_id = s.product_id
    GROUP BY  p.product_id,p.product_name,p.category
)
SELECT product_id,product_name,category,total
FROM cte
WHERE rnk =1;


-- Calculate cumulative sales using SUM() OVER().
SELECT sale_id,sale_date,total_amount,
    SUM(total_amount) OVER(ORDER BY sale_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative
FROM fact_sales;

-- Calculate the average sale amount using AVG() OVER().
SELECT sale_id,sale_date,total_amount,
        AVG(total_amount) OVER(ORDER BY sale_date)
FROM fact_sales;


-- Generate customer-wise revenue using a Common Table Expression (CTE).
WITH cte AS
    (
    SELECT c.customer_id,c.customer_name,SUM(s.total_amount) AS revenue
    FROM dim_customers c
    JOIN fact_sales s
        ON c.customer_id = s.customer_id
    GROUP BY c.customer_id,c.customer_name
    ORDER BY revenue DESC
    )
SELECT * FROM cte;

-- Display customers whose spending is greater than the average spending.

-- with cte 
WITH spending_cte AS 
    (
    SELECT c.customer_id,c.customer_name,SUM(s.total_amount) AS spending
    FROM dim_customers c 
    JOIN fact_sales s 
        ON c.customer_id = s.customer_id
    GROUP BY  c.customer_id,c.customer_name
    )

SELECT customer_id,customer_name,spending
FROM spending_cte
WHERE spending >  (SELECT AVG(spending) FROM spending_cte);


-- without cte 
-- SELECT c.customer_id,c.customer_name,SUM(s.total_amount) AS spending
-- FROM dim_customers c 
-- JOIN fact_sales s 
--     ON c.customer_id = s.customer_id
-- GROUP BY  c.customer_id,c.customer_name
-- HAVING SUM(s.total_amount) > 
--     (
--     SELECT AVG(spending2) 
--     FROM
--         (
--         SELECT customer_id,SUM(total_amount) AS spending2
--         FROM fact_sales 
--         GROUP BY customer_id
--         )t1
--     );


-- Create a View named SALES_REPORT.
CREATE VIEW SALES_REPORT AS 
SELECT * FROM fact_sales;

-- Create a Materialized View named TOP_CUSTOMERS.
CREATE MATERIALIZED VIEW TOP_CUSTOMERS AS 
SELECT customer_id,SUM(total_amount) AS sales 
FROM fact_sales
GROUP BY customer_id;

-- Query both views.
SELECT * FROM sales_report;
SELECT * FROM top_customers;


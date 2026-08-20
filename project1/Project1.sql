CREATE WAREHOUSE sales_wh
with 
WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60;

USE WAREHOUSE sales_wh;

CREATE DATABASE CUSTOMER_SALES_DB;
USE DATABASE CUSTOMER_SALES_DB;

CREATE SCHEMA SALES_SCHEMA;
USE SCHEMA SALES_SCHEMA;

CREATE STAGE SALES_STAGE;

CREATE FILE FORMAT CSV_FORMAT
TYPE = 'csv'
FIELD_DELIMITER = ','
SKIP_HEADER= 1
SKIP_BLANK_LINES=TRUE;

LIST @SALES_STAGE;

CREATE TABLE DIM_CUSTOMERS(
CUSTOMER_ID INT PRIMARY KEY,
FIRST_NAME VARCHAR(50),
LAST_NAME VARCHAR(50),
EMAIL VARCHAR(100) UNIQUE,
PHONE VARCHAR(15) UNIQUE,
ADDRESS VARCHAR(100)
);

CREATE TABLE DIM_FOODITEMS(
FOOD_ID INT PRIMARY KEY,
NAME VARCHAR(50),
PRICE NUMBER(10,2),
CATEGORY  VARCHAR(50),
AVAILABILITY VARCHAR(50)
);
SHOW TABLES;

CREATE TABLE FACT_ORDERS(
ORDER_ID INT PRIMARY KEY,
CUSTOMER_ID INT NOT NULL,
FOOD_ID INT NOT NULL,
QUANTITY INT,
ORDER_DATE DATE,
STATUS VARCHAR(50),
TOTAL_AMOUNT NUMBER(10,2),
FOREIGN KEY (CUSTOMER_ID) REFERENCES DIM_CUSTOMERS(CUSTOMER_ID),
FOREIGN KEY (FOOD_ID) REFERENCES DIM_FOODITEMS(FOOD_ID)
);

COPY INTO DIM_CUSTOMERS
FROM @SALES_STAGE
FILES=('customers.csv')
file_format = (format_name='CSV_FORMAT');

COPY INTO DIM_FOODITEMS
FROM @SALES_STAGE
FILES=('fooditems.csv')
file_format = (format_name='CSV_FORMAT');

COPY INTO FACT_ORDERS
FROM @SALES_STAGE
FILES = ('orders.csv')
FILE_FORMAT=(FORMAT_NAME='CSV_FORMAT');


SELECT * FROM DIM_CUSTOMERS;
SELECT * FROM DIM_FOODITEMS;
SELECT * FROM FACT_ORDERS;


-- Customer-wise Sales
SELECT c.CUSTOMER_ID AS "CUSTOMER ID",
    CONCAT(c.FIRST_NAME,' ',c.LAST_NAME)AS "CUSTOMER NAME",
    SUM(o.TOTAL_AMOUNT) AS "TOTAL AMOUNT"
    
FROM DIM_CUSTOMERS c  
JOIN FACT_ORDERS o  
    ON c.CUSTOMER_ID = o.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID,FIRST_NAME,LAST_NAME
ORDER BY c.CUSTOMER_ID;


-- Highest Spending Customer
SELECT c.customer_id AS "Customer id",CONCAT(c.first_name,' ',c.last_name)AS "CUSTOMER NAME", SUM(o.total_amount) AS "TOTAL AMOUNT"
FROM DIM_CUSTOMERS c  
JOIN FACT_ORDERS o 
    ON c.customer_id = o.customer_id
GROUP BY  c.customer_id,first_name,last_name
HAVING SUM(o.total_amount) = 
    (
    SELECT MAX(total) 
    FROM   
        (  
        SELECT SUM(o2.total_amount) AS total
        FROM FACT_ORDERS o2
        GROUP BY o2.customer_id
        )t
    
    );
    
-- without sub query 
-- SELECT c.customer_id,CONCAT(c.first_name,' ',c.last_name)AS CUSTOMER_NAME,SUM(o.total_amount)
-- FROM FACT_ORDERS o
-- JOIN DIM_CUSTOMERS c 
--     ON c.customer_id = o.customer_id
-- GROUP BY c.customer_id,c.first_name,c.last_name
-- ORDER BY SUM(o.total_amount) DESC
-- LIMIT 1 ;



-- Calculate the Total Business Revenue
SELECT SUM(total_amount) FROM FACT_ORDERS;


-- Generate a Category-wise Revenue Report
SELECT category,SUM(o.total_amount)
FROM DIM_FOODITEMS f  
JOIN FACT_ORDERS o  
    ON f.food_id = o.food_id
GROUP BY category
ORDER BY SUM(o.total_amount) DESC;

-- Generate an Order Status-wise Revenue Report.
SELECT status,SUM(total_amount)
FROM FACT_ORDERS
GROUP BY status 
ORDER BY SUM(total_amount);

-- Display the Top Three Customers based on their total spending
SELECT  c.customer_id AS "customer id",CONCAT(c.first_name,' ',c.last_name)AS "CUSTOMER NAME", SUM(o.total_amount) AS "TOTAL AMOUNT"
FROM DIM_CUSTOMERS c 
JOIN FACT_ORDERS o 
    ON c.customer_id= o.customer_id
GROUP BY c.customer_id,c.first_name,c.last_name
ORDER BY "TOTAL AMOUNT" DESC
LIMIT 3;


-- Generate a Customer Purchase Frequency Report showing
SELECT  c.customer_id AS "customer id",CONCAT(c.first_name,' ',c.last_name)AS "CUSTOMER NAME", COUNT(o.order_id) AS "total orders"
FROM DIM_CUSTOMERS c 
JOIN FACT_ORDERS o 
    ON c.customer_id= o.customer_id
GROUP BY c.customer_id,c.first_name,c.last_name
ORDER BY "total orders" DESC,"customer id" ASC;

-- Display all Delivered Orders only
SELECT * 
FROM FACT_ORDERS 
WHERE status='Delivered';

-- Display all orders placed after 12 July 2026

SELECT * 
FROM fact_orders
WHERE order_date >'2026-07-12';


-- Create a View named CUSTOMER_SALES_REPORT containing:
-- Customer ID
-- Customer Name
-- Total Amount Spent

CREATE VIEW CUSTOMER_SALES_REPORT AS
SELECT 
        c.customer_id AS "Customer ID",
        CONCAT(c.first_name,' ',c.last_name) AS "Customer Name",
        SUM(o.total_amount) AS "Total Amount Spent"
FROM DIM_CUSTOMERS c 
JOIN FACT_ORDERS o 
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id,c.first_name,c.last_name;

-- Retrieve all records from the created View
SELECT * FROM CUSTOMER_SALES_REPORT;

-- Sort the View data in descending order of Total Amount Spent
SELECT * FROM CUSTOMER_SALES_REPORT ORDER BY "Total Amount Spent" DESC;


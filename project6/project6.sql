CREATE WAREHOUSE rev_wh
WITH 
WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60;
USE WAREHOUSE rev_wh;

CREATE DATABASE rev_db;
USE DATABASE rev_db;

CREATE SCHEMA sales_schema;
USE SCHEMA sales_schema;

CREATE FILE FORMAT csv_format
TYPE = 'csv'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
SKIP_BLANK_LINES = TRUE;

CREATE STAGE sales_stage
FILE_FORMAT = csv_format;

LIST @sales_stage;

CREATE TABLE customers(
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(50),
    city VARCHAR(50),
    state VARCHAR(50),
    membership VARCHAR(50)
);

CREATE TABLE products(
product_id INT PRIMARY KEY,
product_name VARCHAR(20),
category VARCHAR(20),
brand VARCHAR(20),
price DECIMAL(10,2)
);

CREATE OR REPLACE TABLE branches(
branch_id INT PRIMARY KEY,
branch_name VARCHAR(25),
city VARCHAR(20),
state VARCHAR(20),
region VARCHAR(20),
manager_name VARCHAR(20)
);

CREATE TABLE t_date(
date_id INT PRIMARY KEY ,
date DATE,
day INT,
day_name VARCHAR(20),
week_no INT,
month VARCHAR(10),
quarter VARCHAR(5),
year INT,
is_weekend BOOLEAN
);

CREATE TABLE sales (
sale_id INT PRIMARY KEY ,
customer_id INT,
product_id INT ,
branch_id INT ,
date_id INT ,
quantity INT ,
total_amount DECIMAL(10,2),

FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
FOREIGN KEY (product_id) REFERENCES products(product_id),
FOREIGN KEY (branch_id) REFERENCES branches(branch_id),
FOREIGN KEY (date_id) REFERENCES t_date(date_id)
);

COPY INTO customers
FROM @sales_stage
FILES = ('customers.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

COPY INTO products 
FROM @sales_stage
FILES = ('products.csv')
FILE_FORMAT = (FORMAT_NAME = 'csv_format');

COPY INTO branches
FROM @sales_stage/branches.csv;

COPY INTO t_date
FROM @sales_stage/calendar.csv;

COPY INTO sales 
FROM @sales_stage/sales.csv;

-- SELECT  $1, $2,$3,$4,$5,$6
-- FROM @sales_stage/branches.csv;

CREATE TABLE dim_state(
state_id INT PRIMARY KEY AUTOINCREMENT,
state_name VARCHAR(50)
);

CREATE TABLE dim_city(
city_id INT PRIMARY KEY AUTOINCREMENT,
city_name VARCHAR(50),
state_id INT REFERENCES dim_state(state_id)
); 

CREATE TABLE dim_customer(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(50),
city_id INT,
membership VARCHAR(10),
FOREIGN KEY (city_id) REFERENCES dim_city(city_id)
);

CREATE OR REPLACE TABLE dim_category(
category_id INT PRIMARY KEY AUTOINCREMENT,
category_name VARCHAR(30)
);

CREATE OR REPLACE TABLE dim_brand(
brand_id INT PRIMARY KEY AUTOINCREMENT,
brand_name VARCHAR(30)
);

CREATE TABLE dim_products(
product_id INT PRIMARY KEY,
product_name VARCHAR(30),
category_id INT NOT NULL,
brand_id INT NOT NULL,
price DECIMAL(10,2),
FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
FOREIGN KEY (brand_id) REFERENCES dim_brand(brand_id)
);

CREATE TABLE dim_region(
region_id INT PRIMARY KEY AUTOINCREMENT,
region_name VARCHAR(30)
);

ALTER TABLE dim_state
ADD region_id INT NOT NULL;

ALTER TABLE dim_state
ADD FOREIGN KEY (region_id) REFERENCES dim_region(region_id);


CREATE TABLE dim_branches(
branch_id INT PRIMARY KEY,
branch_name VARCHAR(50),
city_id INT,
manager_name VARCHAR(30),
FOREIGN KEY (city_id) REFERENCES dim_city(city_id)
);

CREATE TABLE dim_year(
year_id INT PRIMARY KEY AUTOINCREMENT,
year INT 
);

CREATE OR REPLACE TABLE dim_quarter(
quarter_id INT PRIMARY KEY AUTOINCREMENT,
quarter varchar(5),
year_id INT REFERENCES dim_year(year_id),

CONSTRAINT uk_quarter UNIQUE(quarter,year_id),

FOREIGN KEY (year_id) REFERENCES dim_year(year_id)
 );

CREATE TABLE dim_month (
month_id INT PRIMARY KEY AUTOINCREMENT,
month_name VARCHAR(10),
quarter_id INT REFERENCES dim_quarter(quarter_id),

CONSTRAINT uk_month UNIQUE(month_name,quarter_id)
);

CREATE TABLE dim_date(
date_id INT PRIMARY KEY ,
date DATE,
day INT,
day_name VARCHAR(50),
week_no INT,
is_weekend BOOLEAN,
month_id INT NOT NULL,

FOREIGN KEY (month_id) REFERENCES dim_month(month_id)
);

ALTER TABLE sales 
RENAME TO fact_sales;


INSERT INTO dim_region(region_name)
SELECT DISTINCT region FROM branches; 

SELECT * FROM dim_region;

INSERT INTO dim_state(state_name,region_id) 
SELECT b.state,r.region_id,
FROM branches b
JOIN dim_region r 
    ON b.region = r.region_name;

SELECT * FROM dim_state;

INSERT INTO dim_city(city_name,state_id)
SELECT b.city,s.state_id
FROM dim_state s 
JOIN branches b
    ON b.state= s.state_name;  
    
SELECT * FROM dim_city;


insert into dim_branches(branch_id, branch_name, manager_name, city_id)
select t.branch_id, t.branch_name, t.manager_name, c.city_id
from branches t
join dim_state s on t.state=s.state_name
join dim_city c on t.city=c.city_name
and c.state_id=s.state_id;

select*from dim_branches;

insert into dim_category(category_name)
select distinct category from products;

select*from dim_category;

insert into dim_brand(brand_name)
select distinct p.brand from products p;


select*from dim_brand;

insert into dim_products(product_id, product_name, price, brand_id, category_id)
select p.product_id, p.product_name, p.price, b.brand_id, c.category_id
from products p 
join dim_category c on p.category=c.category_name
join dim_brand b on p.brand=b.brand_name;

select*from dim_products;

insert into dim_customer(customer_id, customer_name, membership, city_id)
select c.customer_id, c.customer_name, c.membership, d.city_id
from customers c 
join dim_state s on c.state=s.state_name
join dim_city d on c.city=d.city_name
and s.state_id=d.state_id;

select*from dim_customer;

insert into dim_year(year)
select distinct year from t_date;

select*from dim_year;

insert into dim_quarter(quarter, year_id)
select distinct d.quarter, y.year_id
from t_date d
join dim_year y on d.year=y.year;

select*from dim_quarter;

insert into dim_month(month_name, quarter_id)
select distinct d.month, q.quarter_id from 
t_date d
join dim_year y on d.year=y.year
join dim_quarter q on d.quarter=q.quarter
and q.year_id=y.year_id;

select*from dim_month;

insert into dim_date(date_id, date, day, day_name, week_no, is_weekend, month_id)
select d.date_id, d.date, d.day, d.day_name, d.week_no, d.is_weekend, m.month_id
from t_date d
join dim_year y on d.year=y.year
join dim_quarter q on d.quarter=q.quarter
and q.year_id=y.year_id
join dim_month m on d.month=m.month_name
and m.quarter_id=q.quarter_id;

select*from dim_date;

-- ==========================================================================

-- Customer-wise Sales Report
SELECT c.customer_id,customer_name,SUM(s.total_amount) AS total
FROM dim_customer c 
JOIN fact_sales s 
    ON c.customer_id = s.customer_id
GROUP BY c.customer_id,customer_name
ORDER BY total DESC;

-- Product-wise Revenue Report
SELECT p.product_id,product_name,SUM(s.total_amount) AS total
FROM dim_products p
JOIN fact_sales s 
    ON p.product_id = s.product_id
GROUP BY p.product_id,product_name
ORDER BY total DESC;

-- Brand-wise Revenue Report
SELECT b.branch_id,branch_name,SUM(s.total_amount) AS total
FROM dim_branches b
JOIN fact_sales s 
    ON b.branch_id = s.branch_id
GROUP BY b.branch_id,branch_name
ORDER BY total DESC;


-- Category-wise Revenue Report
SELECT c.category_id,c.category_name,SUM(s.total_amount) AS total
FROM dim_category c
JOIN dim_products p  
    ON c.category_id = p.category_id
JOIN fact_sales s 
    ON s.product_id = p.product_id
GROUP BY c.category_id,c.category_name
ORDER BY total DESC;


-- City-wise Sales Report
SELECT c.city_id,c.city_name,SUM(s.total_amount) AS total
FROM dim_city c 
JOIN dim_branches b 
    ON c.city_id = b.city_id
JOIN fact_sales s 
    ON b.branch_id = s.branch_id
GROUP BY c.city_id,c.city_name
ORDER BY total DESC;


-- State-wise Revenue Report
SELECT ds.state_id,ds.state_name,SUM(s.total_amount) AS total
FROM dim_state ds
JOIN dim_city c
    ON c.state_id = ds.state_id
JOIN dim_branches b 
    ON b.city_id= c.city_id
JOIN fact_sales s 
    ON b.branch_id = s.branch_id
GROUP BY ds.state_id,ds.state_name
ORDER BY total DESC;


-- Region-wise Revenue Report
SELECT r.region_id,r.region_name,SUM(s.total_amount) AS total
FROM dim_region r
JOIN dim_state st 
    ON r.region_id = st.region_id
JOIN dim_city c 
    ON st.state_id = c.state_id
JOIN dim_branches b 
    ON b.city_id = c.city_id
JOIN fact_sales s
    ON b.branch_id = s.branch_id
GROUP BY r.region_id,r.region_name
ORDER BY total DESC;


-- Monthly Revenue Report
SELECT m.month_id,m.month_name,SUM(s.total_amount) AS total
FROM dim_month m 
JOIN dim_date d 
    ON m.month_id = d.month_id
JOIN fact_sales s 
    ON d.date_id = s.date_id
GROUP BY m.month_id,m.month_name
ORDER BY total DESC;


-- Quarterly Revenue Report
SELECT q.quarter_id,q.quarter,SUM(s.total_amount) AS total
FROM dim_quarter q
JOIN dim_month m 
    ON m.quarter_id = q.quarter_id
JOIN dim_date d 
    ON d.month_id = m.month_id
JOIN fact_sales s 
    ON d.date_id = s.date_id
GROUP BY q.quarter_id,q.quarter
ORDER BY total DESC;



-- Top 10 Customers
SELECT * 
FROM 
    (
        SELECT c.customer_id,c.customer_name,SUM(total_amount) AS revenue,RANK() OVER(ORDER BY revenue DESC) rnk
        FROM dim_customer c 
        LEFT JOIN fact_sales s
            ON c.customer_id = s.customer_id
        GROUP BY  c.customer_id,c.customer_name
    )t
WHERE rnk <=10
;



-- Top 10 Products
SELECT * 
FROM 
    (
        SELECT p.product_id ,p.product_name ,SUM(total_amount) AS revenue,RANK() OVER(ORDER BY revenue DESC) rnk
        FROM dim_products p 
        LEFT JOIN fact_sales s
            ON p.product_id = s.product_id
        GROUP BY  p.product_id ,p.product_name 
    )t
WHERE rnk <=10
;


-- Top 10 Branches
SELECT * 
FROM 
    (
        SELECT b.branch_id ,b.branch_id ,SUM(total_amount) AS revenue,RANK() OVER(ORDER BY revenue DESC) rnk
        FROM dim_branches b 
        LEFT JOIN fact_sales s
            ON b.branch_id = s.branch_id
        GROUP BY b.branch_id ,b.branch_id 
    )t
WHERE rnk <=10
;






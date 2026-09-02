Problem Statement:
-----------------
A nationwide retail chain has expanded its operations across multiple
cities and now receives daily sales data from all its branches. 
To improve reporting and decision-making, the company has migrated its data to the Snowflake Cloud Data Warehouse.

Every day, the company receives four CSV files containing customer details, product information, branch information, and sales transactions. The data engineering team must load these files into Snowflake, while the business intelligence team needs analytical reports to identify top-performing products, branches, and customers.

Your task is to build the Snowflake environment, load the data, and generate business reports that help management understand sales trends and customer purchasing behavior.

Project Objectives:
---------------------
After completing this project, students will be able to:

Load multiple datasets into Snowflake.
Perform multi-table joins.
Use aggregate functions.
Apply Window Functions.
Use Common Table Expressions (CTEs).
Create Views and Materialized Views.
Generate business intelligence reports.

Input Files:
------------
The company provides the following CSV files:

customers.csv
products.csv
branches.csv
sales.csv


customers.csv
--------------
customer_id,customer_name,city,membership
1,Amit,Hyderabad,Gold
2,Priya,Bengaluru,Silver
3,Rahul,Chennai,Gold
4,Neha,Pune,Silver
5,Arjun,Delhi,Platinum


products.csv
------------
product_id,product_name,category,price
101,Laptop,Electronics,60000
102,Mobile,Electronics,25000
103,Headphones,Accessories,3000
104,Keyboard,Accessories,1500
105,Monitor,Electronics,12000


branches.csv
-------------
branch_id,branch_name,city
1,Hyderabad Branch,Hyderabad
2,Bengaluru Branch,Bengaluru
3,Delhi Branch,Delhi


sales.csv
----------
sale_id,customer_id,product_id,branch_id,quantity,sale_date,total_amount
1,1,101,1,1,2026-07-01,60000
2,2,102,2,2,2026-07-02,50000
3,3,103,2,3,2026-07-03,9000
4,4,104,1,5,2026-07-04,7500
5,5,105,3,2,2026-07-05,24000
6,1,102,1,1,2026-07-06,25000
7,2,105,2,1,2026-07-07,12000
8,3,101,3,1,2026-07-08,60000
9,4,103,1,2,2026-07-09,6000
10,5,102,3,1,2026-07-10,25000
11,1,104,1,4,2026-07-11,6000
12,2,103,2,2,2026-07-12,6000


Your Tasks:
-----------
Phase-1: Snowflake Environment
-------------------------------
Create a Warehouse named RETAIL_WH.
Create a Database named RETAIL_DB.
Create a Schema named SALES_SCHEMA.
Create a CSV File Format.
Create an Internal Stage.


Phase-2: Data Loading
----------------------
Upload all four CSV files.
Create the required tables.
Load the data using COPY INTO.
Verify the imported records.

Phase-3: SQL Analytics
-------------------------
Display all customers.
Display all products.
Display all branches.
Display all sales transactions.
Calculate total business revenue.
Generate customer-wise sales.
Generate branch-wise sales.
Generate product-wise sales.
Generate category-wise sales.
Display the highest revenue branch.
Display the highest spending customer.
Display the top three products by revenue.
Display the top three customers by spending.


Phase-4: Window Functions
---------------------------
Rank customers based on total spending.
Rank branches based on total sales.
Display the top-selling product in each category using ROW_NUMBER().
Calculate cumulative sales using SUM() OVER().
Calculate the average sale amount using AVG() OVER().


Phase-5: CTE
--------------
Generate customer-wise revenue using a Common Table Expression (CTE).
Display customers whose spending is greater than the average spending.


Phase-6: Views
-----------------
Create a View named SALES_REPORT.
Create a Materialized View named TOP_CUSTOMERS.
Query both views.



Expected Outputs:
-------------
You should generate the following reports:
All Customers
All Products
All Branches
Customer-wise Sales Report
Branch-wise Revenue Report
Product-wise Revenue Report
Category-wise Revenue Report
Highest Revenue Branch
Highest Spending Customer
Top Three Products
Top Three Customers
Customer Ranking
Branch Ranking
Top Product in Each Category
Cumulative Sales Report
Average Sales Report
Customers Spending Above Average
Sales Report View
Materialized View Report



*/

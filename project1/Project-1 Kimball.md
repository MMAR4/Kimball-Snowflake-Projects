/*
PROJECT-1: Customer Sales Analytics using Snowflake Cloud Data Warehouse

Problem Statement:
An online retail company has recently migrated its operational database to the Snowflake Cloud Data Warehouse to improve reporting, 
business intelligence, and decision-making.

Every day, the company receives three CSV files from multiple regional stores containing customer information, food item details, 
and order transactions. The data engineering team is responsible for loading these files into Snowflake and making the data available
 for analytical reporting.

The management team wants to answer important business questions such as:
-------------------------------------------------------------------------
Who are the highest spending customers?
What is the total business revenue?
Which food category generates the highest revenue?
How many orders has each customer placed?
Which orders are delivered and which are still being processed?

Your task is to use Snowflake to create the required environment, load the data from CSV files, and generate analytical
reports for the management team.

Objective:By completing this project, students will learn how to:
---------
Create Snowflake objects
Load CSV files into Snowflake
Perform analytical SQL queries
Create reusable Views
Generate business reports from warehouse data


Input Files
-----------
These files must be uploaded into the Snowflake Internal Stage and loaded into the corresponding tables using the COPY INTO command.

customers.csv
--------------
customer_id,first_name,last_name,email,phone,address
1,Amit,Sharma,amit@gmail.com,9876543210,Delhi
2,Priya,Singh,priya@yahoo.com,9876541009,Mumbai
3,Rahul,Verma,rahul@gmail.com,8876540998,Bengaluru
4,Neha,Patel,neha@yahoo.com,7876540987,Ahmedabad
5,Arjun,Gupta,arjun@gmail.com,6876541234,Hyderabad

Description
--------------
This file contains the customer information.

Column	            Description
------              -----------
customer_id     	Unique Customer ID
first_name	        Customer First Name
last_name	        Customer Last Name
email	            Email Address
phone	            Contact Number
address	            City


fooditems.csv
-------------
food_id,name,price,category,availability
1,Paneer Butter Masala,250,Main Course,Available
2,Chicken Biryani,300,Main Course,Available
3,Masala Dosa,120,Breakfast,Available
4,Samosa,30,Snacks,Available
5,Gulab Jamun,50,Dessert,Available

Description
-----------
This file contains food item details.
| Column       | Description       |
| ------------ | ----------------- |
| food_id      | Unique Food ID    |
| name         | Food Item Name    |
| price        | Price             |
| category     | Food Category     |
| availability | Item Availability |


orders.csv
-----------
order_id,customer_id,food_id,quantity,order_date,status,total_amount
1,1,2,2,2026-07-10 12:30:00,Delivered,600
2,2,1,1,2026-07-11 13:15:00,Delivered,250
3,3,3,3,2026-07-11 09:00:00,Delivered,360
4,4,4,5,2026-07-12 17:45:00,Delivered,150
5,5,5,4,2026-07-12 21:00:00,Delivered,200
6,1,1,1,2026-07-13 14:00:00,Delivered,250
7,2,2,2,2026-07-13 20:30:00,Delivered,600
8,3,5,2,2026-07-14 19:15:00,Delivered,100
9,4,3,2,2026-07-15 08:30:00,Delivered,240
10,5,2,1,2026-07-15 13:00:00,Delivered,300
11,1,4,10,2026-07-16 18:00:00,Delivered,300
12,2,3,1,2026-07-17 09:30:00,Preparing,120


Description:This file contains customer order transactions.
---------------
| Column       | Description            |
| ------------ | ---------------------- |
| order_id     | Unique Order ID        |
| customer_id  | Customer ID            |
| food_id      | Ordered Food Item      |
| quantity     | Quantity Ordered       |
| order_date   | Date and Time of Order |
| status       | Order Status           |
| total_amount | Total Bill Amount      |


Summary of Input Files
---------------------
| File Name     | Number of Records |
| ------------- | ----------------- |
| customers.csv | 5                 |
| fooditems.csv | 5                 |
| orders.csv    | 12                |

Tasks:
---------
Phase 1: Snowflake Environment Setup
--------------------------------------
Task 1:Create a Virtual Warehouse named SALES_WH.

Task 2:Create a Database named CUSTOMER_SALES_DB.

Task 3:Create a Schema named SALES_SCHEMA.

Task 4:Select the Database and Schema for the current session.

Task 5:Create a CSV File Format to load the CSV files.

The file format should:
Read CSV files
Skip the header row
Use comma (,) as the field delimiter

Task 6:Create an Internal Stage named SALES_STAGE to store the CSV files.

Phase 2: Data Loading
-----------------------
Task 7:Upload the following files into the Internal Stage.
customers.csv
fooditems.csv
orders.csv

Task 8:Create the following tables.
CUSTOMERS
FOODITEMS
ORDERS
Choose appropriate data types for each column.

Task 9:Load all CSV files into their respective tables using the COPY INTO command.

Task 10:Verify that the data has been loaded successfully by displaying all records from each table.

Phase 3: Data Analysis
--------------------------

Write SQL queries to generate the following reports.

Task 11:Display all customer details.

Task 12:Display all food item details.

Task 13:Display all order details.

Task 14:Generate a Customer-wise Sales Report showing:
Customer ID
Customer Name
Total Amount Spent

Task 15:Find the Highest Spending Customer.

Task 16:Calculate the Total Business Revenue.

Task 17:Generate a Category-wise Revenue Report.
The report should display:
Food Category
Total Revenue

Task 18:Generate an Order Status-wise Revenue Report.
The report should display:
Order Status
Total Revenue

Task 19:Display the Top Three Customers based on their total spending.

Task 20:Generate a Customer Purchase Frequency Report showing:
Customer ID
Customer Name
Number of Orders Placed

Task 21:Display all Delivered Orders only.

Task 22:Display all orders placed after 12 July 2026.

Phase 4: Views
---------------
Task 23:Create a View named CUSTOMER_SALES_REPORT containing:
Customer ID
Customer Name
Total Amount Spent

Task 24:Retrieve all records from the created View.

Task 25:Sort the View data in descending order of Total Amount Spent.


Submission Requirements:
------------------------
Students should submit:
SQL script containing all DDL, DML, and analytical queries.
Screenshots showing:
Warehouse creation
Database and Schema creation
Stage creation
Successful data loading
Results of all analytical reports
View creation and execution


Expected Outputs:
-------------------

Expected Output-1: Display All Customers
------------------
| Customer ID | First Name | Last Name | Email                                     | City      |
| ----------- | ---------- | --------- | ----------------------------------------- | --------- |
| 1           | Amit       | Sharma    | [amit@gmail.com](mailto:amit@gmail.com)   | Delhi     |
| 2           | Priya      | Singh     | [priya@yahoo.com](mailto:priya@yahoo.com) | Mumbai    |
| 3           | Rahul      | Verma     | [rahul@gmail.com](mailto:rahul@gmail.com) | Bengaluru |
| 4           | Neha       | Patel     | [neha@yahoo.com](mailto:neha@yahoo.com)   | Ahmedabad |
| 5           | Arjun      | Gupta     | [arjun@gmail.com](mailto:arjun@gmail.com) | Hyderabad |


Expected Output-2:Customer-wise Sales Report
-----------------
| Customer ID | Customer Name | Total Spent |
| ----------- | ------------- | ----------: |
| 1           | Amit Sharma   |        1150 |
| 2           | Priya Singh   |         970 |
| 3           | Rahul Verma   |         460 |
| 4           | Neha Patel    |         390 |
| 5           | Arjun Gupta   |         500 |


Expected Output-3:Highest Spending Customer
------------------
| Customer ID | Customer Name | Total Spent |
| ----------- | ------------- | ----------: |
| 1           | Amit Sharma   |        1150 |


Expected Output-4:Total Business Revenue
-----------------
| Total Revenue |
| ------------: |
|          3470 |



Expected Output-5:Category-wise Revenue
-------------------
| Category    | Revenue |
| ----------- | ------: |
| Main Course |    1750 |
| Breakfast   |     720 |
| Snacks      |     450 |
| Dessert     |     300 |

Expected Output-6:Order Status-wise Revenue
-----------------
| Order Status | Revenue |
| ------------ | ------: |
| Delivered    |    3350 |
| Preparing    |     120 |


Expected Output-7:Top Three Customers
--------------------

| Rank | Customer Name | Total Spent |
| ---: | ------------- | ----------: |
|    1 | Amit Sharma   |        1150 |
|    2 | Priya Singh   |         970 |
|    3 | Arjun Gupta   |         500 |



Expected Output-8:Customer Purchase Frequency
-------------------
| Customer ID | Customer Name | Orders Placed |
| ----------- | ------------- | ------------: |
| 1           | Amit Sharma   |             3 |
| 2           | Priya Singh   |             3 |
| 3           | Rahul Verma   |             2 |
| 4           | Neha Patel    |             2 |
| 5           | Arjun Gupta   |             2 |


Expected Output-9:Delivered Orders
--------------------
| Order ID | Customer ID | Food ID | Status    | Total Amount |
| -------: | ----------: | ------: | --------- | -----------: |
|        1 |           1 |       2 | Delivered |          600 |
|        2 |           2 |       1 | Delivered |          250 |
|        3 |           3 |       3 | Delivered |          360 |
|        4 |           4 |       4 | Delivered |          150 |
|        5 |           5 |       5 | Delivered |          200 |
|        6 |           1 |       1 | Delivered |          250 |
|        7 |           2 |       2 | Delivered |          600 |
|        8 |           3 |       5 | Delivered |          100 |
|        9 |           4 |       3 | Delivered |          240 |
|       10 |           5 |       2 | Delivered |          300 |
|       11 |           1 |       4 | Delivered |          300 |




Expected Output-10:Orders Placed After 12 July 2026
------------------
| Order ID | Customer Name | Order Date          | Status    | Total Amount |
| -------: | ------------- | ------------------- | --------- | -----------: |
|        6 | Amit Sharma   | 2026-07-13 14:00:00 | Delivered |          250 |
|        7 | Priya Singh   | 2026-07-13 20:30:00 | Delivered |          600 |
|        8 | Rahul Verma   | 2026-07-14 19:15:00 | Delivered |          100 |
|        9 | Neha Patel    | 2026-07-15 08:30:00 | Delivered |          240 |
|       10 | Arjun Gupta   | 2026-07-15 13:00:00 | Delivered |          300 |
|       11 | Amit Sharma   | 2026-07-16 18:00:00 | Delivered |          300 |
|       12 | Priya Singh   | 2026-07-17 09:30:00 | Preparing |          120 |




Section 5: Concepts Covered
----------------------------
After completing this project, students will gain hands-on experience with the following Snowflake concepts:

Snowflake Environment
---------------------
Virtual Warehouse
Database
Schema
Internal Stage
File Format

Data Loading
---------------
Uploading CSV Files
COPY INTO
Data Verification


SQL Concepts
---------------
SELECT
WHERE
ORDER BY
GROUP BY
Aggregate Functions (SUM(), COUNT())
INNER JOIN
LIMIT


Snowflake Objects
--------------------
CREATE VIEW
Querying Views


Business Analytics
---------------------
Customer Spending Analysis
Revenue Analysis
Category-wise Sales Analysis
Order Status Analysis
Customer Purchase Frequency
Top Customer Identification


Learning Outcomes:
--------------------
After successfully completing this project, you will be able to:

1.Create and configure a Snowflake environment.
2.Create databases, schemas, stages, and file formats.
3.Design tables using appropriate data types.
4.Load CSV files into Snowflake using the COPY INTO command.
5.Validate the imported data.
6.Write SQL queries to analyze business data.
7.Use aggregate functions and joins to generate reports.
8.Create reusable views for reporting.
9.Interpret analytical results to support business decision-making.
10.Apply Snowflake concepts in a real-world data warehousing scenario.


Submission Guidelines:
--------------------------
you must submit the following:

1. SQL Script:A single SQL script containing:
-------------
Warehouse creation
Database creation
Schema creation
File Format creation
Stage creation
Table creation
Data loading (COPY INTO)
All SQL queries
View creation


2. Screenshots: you should include screenshots showing:
----------------
Warehouse created successfully
Database created successfully
Schema created successfully
Internal Stage created
Files uploaded to Stage
Tables created
Data loaded successfully
Output of all analytical queries
View creation and execution
*/

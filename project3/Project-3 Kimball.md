PROJECT-3:Enterprise Incremental Sales Data Warehouse using Snowflake
----------
Problem Statement:
-------------------
A multinational retail company has already migrated its operational databases to the Snowflake Cloud Data Warehouse. Initially, the company performed a complete data migration and generated analytical reports for business users.

As the business expanded, new sales transactions started arriving every hour from multiple regional branches. Reloading the complete historical data every time became inefficient and increased processing time.

The data engineering team has been assigned to develop an Incremental Data Warehouse Pipeline capable of loading only newly arrived records while preserving historical data.

To improve warehouse reliability, the company also wants to maintain an audit trail, recover accidentally deleted data, create testing environments without duplicating storage, and automate daily data loading.

Your task is to implement the required Snowflake objects and generate analytical reports using the newly loaded data.

Project Objectives
--------------------
After completing this project, students will be able to 
Perform Incremental Data Loading
Use Snowflake Streams
Automate loading using Tasks
Recover historical data using Time Travel
Create Zero Copy Clones
Validate newly arrived records
Maintain Audit Logs
Generate analytical reports.

Input Files
------------
customers.csv
---------------
customer_id,customer_name,city,membership
1,Amit,Hyderabad,Gold
2,Priya,Bangalore,Silver
3,Rahul,Chennai,Gold
4,Neha,Pune,Silver
5,Arjun,Delhi,Platinum


products.csv
-------------
product_id,product_name,category,price
101,Laptop,Electronics,60000
102,Mobile,Electronics,25000
103,Keyboard,Accessories,1500
104,Mouse,Accessories,800
105,Monitor,Electronics,12000

branches.csv
------------
branch_id,branch_name,state
1,Hyderabad Branch,Telangana
2,Bangalore Branch,Karnataka
3,Delhi Branch,Delhi

sales_history.csv
------------------
sale_id,customer_id,product_id,branch_id,quantity,sale_date,total_amount
1,1,101,1,1,2026-07-01,60000
2,2,102,2,2,2026-07-02,50000
3,3,103,2,2,2026-07-03,3000
4,4,104,1,5,2026-07-04,4000
5,5,105,3,2,2026-07-05,24000


new_sales.csv
---------------
sale_id,customer_id,product_id,branch_id,quantity,sale_date,total_amount
6,1,102,1,1,2026-07-06,25000
7,2,105,2,1,2026-07-07,12000
8,3,101,3,1,2026-07-08,60000
9,4,103,1,2,2026-07-09,3000
10,5,102,3,1,2026-07-10,25000

your Tasks:
--------------
Phase-1 : Snowflake Environment
-------------------------------
1.Create Warehouse ENTERPRISE_WH
2.Create Database ENTERPRISE_DB
3.Create Schema SALES_SCHEMA
4.Create CSV File Format
5.Create Internal Stage

Phase-2 : Data Loading
-------------------------
6.Upload all CSV files.
7.Create all required tables.
8.Load sales_history.csv into SALES table.
9.Verify the loaded records.

Phase-3 : Incremental Loading
--------------------------------
10.Create a Stream on the SALES table.
11.Load new_sales.csv.
12.Display only newly inserted records using the Stream.
13.Merge newly arrived records into the SALES table.


Phase-4 : Data Validation
-------------------------
14.Identify duplicate Sale IDs.
15.Identify missing Customer IDs.
16.Display invalid Product IDs.
17.Count total newly inserted records.

Phase-5 : Time Travel
---------------------
18.Delete one sales record.
19.Recover the deleted record using Time Travel.
20.Verify recovery.


Phase-6 : Zero Copy Clone
-------------------------
21.Create a clone named: SALES_TEST
22.Display cloned records.
23.Insert one new record into the clone.
24.Verify that the original SALES table remains unchanged.

Phase-7 : Task Automation
-------------------------
25.Create a Task that automatically performs incremental loading every day.
26.Resume the Task.
27.Verify Task execution.


Phase-8 : Business Analytics
-----------------------------
Generate
28.Customer Revenue Report
29.Branch Revenue Report
30.Product Revenue Report
31.Monthly Revenue Report
32.Highest Revenue Customer
33.Highest Revenue Branch
34.Top Five Products
35.Customer Purchase Frequency
36.Running Revenue
37.Customer Ranking

Phase-9 : Views
----------------
38.Create View: CUSTOMER_REVENUE
39.Create Materialized View: BRANCH_REVENUE
40.Display data from both Views.


Expected Outputs
--------------------

Output-1:Customers Loaded Successfully

Output-2:Products Loaded Successfully

Output-3:Historical Sales Loaded

Output-4:New Sales Captured by Stream

Output-5:Incremental Load Completed

Output-6:Duplicate Record Report

Output-7:Missing Customer Report

Output-8:Recovered Records using Time Travel

Output-9:Clone Created Successfully

Output-10:Original Table Unchanged After Clone Modification

Output-11:Customer Revenue Report

Output-12:Branch Revenue Report

Output-13:Monthly Revenue Report

Output-14:Top Five Customers

Output-15:Top Five Products

Output-16:Customer Ranking

Output-17:Running Revenue

Output-18:Materialized View Output


Snowflake Concepts Covered:
----------------------------
Snowflake Administration:
-------------------------
Warehouse
Database
Schema
Stage
File Format

Data Engineering
----------------
COPY INTO
MERGE
Streams
Tasks
Time Travel
Zero Copy Clone

SQL Analytics:
-------------
JOIN
GROUP BY
HAVING
ORDER BY
CTE
Window Functions
Ranking

Snowflake Objects
-----------------
Views
Materialized Views
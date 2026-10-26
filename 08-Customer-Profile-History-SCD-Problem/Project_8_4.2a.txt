PROJECT 8 — Slowly Changing Dimension: The Problem
---------------------------------------------------
Project Name:Customer Profile History Analysis using Snowflake

1. Problem Statement
--------------------
An online retail company maintains customer information in its 
operational system.

Customer attributes such as:
City
State
Membership
Customer Segment

can change over time.

For example, a customer may initially live in Hyderabad and later move
to Bengaluru. Similarly, a customer may move from Silver membership to 
Gold membership.

The company's management wants to analyze customer information for both:
1.Current customer information
2.Historical customer information

The Data Warehouse team currently stores one row per customer in the 
customer dimension.

When a customer's information changes, if the existing row is simply 
updated, the previous value is lost.

For example:  Before Update
--------------
Customer 101
City       = Hyderabad
Membership = Silver

After the customer moves:After Update
---------------------------------------
Customer 101
City       = Bengaluru
Membership = Gold

The original information:
-------------------------
Hyderabad
Silver

Note:
-------
Management therefore wants the Data Warehouse team to identify and 
demonstrate this Slowly Changing Dimension problem before deciding
how historical changes should be handled.


2. Business Scenario
------------------------
The company initially has the following customer information:
Customer 101 → Hyderabad → Silver
Customer 102 → Warangal  → Gold
Customer 103 → Vijayawada → Silver
Customer 104 → Hyderabad → Gold
Customer 105 → Nagpur → Bronze


Later, some customers change their information.
The company receives a new customer update file containing:
Customer 101 moved from Hyderabad to Bengaluru.
Customer 101 upgraded from Silver to Gold.
Customer 103 moved from Vijayawada to Chennai.
Customer 104 upgraded from Gold to Platinum.

Students must load the initial data and update data into Snowflake 
and demonstrate what historical information is lost when the existing 
dimension row is overwritten.

3. Input Files
---------------
customers_initial.csv
--------------------------
customer_id,customer_name,city,state,membership,segment
101,Amit Sharma,Hyderabad,Telangana,Silver,Regular
102,Priya Reddy,Warangal,Telangana,Gold,Premium
103,Rahul Verma,Vijayawada,Andhra Pradesh,Silver,Regular
104,Neha Patel,Hyderabad,Telangana,Gold,Premium
105,Arjun Gupta,Nagpur,Maharashtra,Bronze,Regular


customer_updates.csv
-----------------------
customer_id,customer_name,city,state,membership,segment
101,Amit Sharma,Bengaluru,Karnataka,Gold,Premium
103,Rahul Verma,Chennai,Tamil Nadu,Gold,Premium
104,Neha Patel,Hyderabad,Telangana,Platinum,Premium


Task 1 — Create Snowflake Database and Schema

Task 2 — Create Initial Customer Dimension
Create:DIM_CUSTOMER
with:
CUSTOMER_KEY
CUSTOMER_ID
CUSTOMER_NAME
CITY
STATE
MEMBERSHIP
SEGMENT

Task 3 — Load Initial Customer Data
Load:customers_initial.csv

into DIM_CUSTOMER.
Students should use a Snowflake stage and COPY INTO.

Expected Output:
Initial Customer Records Loaded Successfully
Total Customers = 5


Task 4 — Display Initial Customer Dimension

CUSTOMER_ID  CUSTOMER_NAME   CITY        STATE             MEMBERSHIP  SEGMENT
--------------------------------------------------------------------------------
101          Amit Sharma     Hyderabad   Telangana         Silver      Regular
102          Priya Reddy     Warangal    Telangana         Gold        Premium
103          Rahul Verma     Vijayawada  Andhra Pradesh    Silver      Regular
104          Neha Patel      Hyderabad   Telangana         Gold        Premium
105          Arjun Gupta     Nagpur      Maharashtra       Bronze      Regular


Task 5 — Load Customer Updates
----------------------------------
Load:customer_updates.csv
into a separate staging table:CUSTOMER_UPDATES

Expected Output:
------------------
Customer Update Records Loaded Successfully

Records Received = 3


Task 6 — Identify Changed Customers
------------------------------------
Compare DIM_CUSTOMER with CUSTOMER_UPDATES.
Identify customers whose attributes have changed.
Students should compare:
CITY
STATE
MEMBERSHIP
SEGMENT

Exact Expected Output
------------------------
CUSTOMER_ID  OLD_CITY    NEW_CITY    OLD_MEMBERSHIP  NEW_MEMBERSHIP
-------------------------------------------------------------------
101          Hyderabad   Bengaluru   Silver          Gold
103          Vijayawada  Chennai     Silver          Gold
104          Hyderabad   Hyderabad   Gold            Platinum

Task 7 — Identify Attribute Changes
-------------------------------------
Students must produce a change report.

Expected Output:
---------------
CUSTOMER_ID  ATTRIBUTE    OLD_VALUE      NEW_VALUE
---------------------------------------------------
101          CITY         Hyderabad      Bengaluru
101          STATE        Telangana      Karnataka
101          MEMBERSHIP   Silver         Gold

103          CITY         Vijayawada     Chennai
103          STATE        Andhra Pradesh Tamil Nadu
103          MEMBERSHIP   Silver         Gold

104          MEMBERSHIP   Gold            Platinum

This output demonstrates the core idea of SCD: a dimension attribute can change over time.


Task 8 — Demonstrate the SCD Problem
-------------------------------------
The company currently updates the existing dimension record.


Task 9 — Display the Updated Dimension
-------
Expected Output:
----------------
CUSTOMER_ID  CUSTOMER_NAME   CITY        STATE             MEMBERSHIP  SEGMENT
--------------------------------------------------------------------------------
101          Amit Sharma     Bengaluru   Karnataka         Gold        Premium
102          Priya Reddy     Warangal    Telangana         Gold        Premium
103          Rahul Verma     Chennai     Tamil Nadu        Gold        Premium
104          Neha Patel      Hyderabad   Telangana         Platinum    Premium
105          Arjun Gupta     Nagpur      Maharashtra       Bronze      Regular


Task 10 — Demonstrate Historical Data Loss
------------
Now answer:

Can the current DIM_CUSTOMER table tell us where Customer 101 lived before the update?

Output:
---------
CUSTOMER_ID  CUSTOMER_NAME  CITY       STATE      MEMBERSHIP
-------------------------------------------------------------
101          Amit Sharma    Bengaluru  Karnataka  Gold

The original information:
-------------------------
Hyderabad
Telangana
Silver

has disappeared from the dimension.


Task 11 — Business Impact Analysis
------------------------------------
Students must identify what information is lost.

Customer 101

Original City:
Hyderabad

Current City:
Bengaluru

Original Membership:
Silver

Current Membership:
Gold


Problem:After overwriting the dimension:
------------------------------------------
Historical City       → LOST
Historical State      → LOST
Historical Membership → LOST

Therefore, the company cannot determine the customer's historical state using the current dimension.

---1.1 Find the top 3 customers who have the maximum count of orders.

SELECT TOP 3  Cust_ID, COUNT(Ord_ID) AS order_count 
FROM e_commerce_data
GROUP BY Cust_ID
ORDER BY order_count DESC;

---1.2. Find the customer whose order took the maximum time to get shipping.

SELECT TOP 1 Cust_ID, MAX(DaysTakenForShipping) AS max_shipping_time
FROM e_commerce_data
GROUP BY Cust_ID
ORDER BY max_shipping_time DESC;

---1.3. Count the total number of unique customers in January and how many of them came back for each month over the entire year in 2011.

SELECT COUNT(DISTINCT Cust_ID)
FROM e_commerce_data
WHERE MONTH(Order_Date) = 1
AND YEAR(Order_Date) = 2011;


SELECT Cust_ID
FROM e_commerce_data
WHERE Year(Order_Date) = 2011
AND Month(Order_Date) = 1
AND Month(Order_Date) = 2
AND Month(Order_Date) = 3
AND Month(Order_Date) = 4
AND Month(Order_Date) = 5
AND Month(Order_Date) = 6
AND Month(Order_Date) = 7
AND Month(Order_Date) = 8
AND Month(Order_Date) = 9
AND Month(Order_Date) = 10
AND Month(Order_Date) = 11
AND Month(Order_Date) = 12;


WITH jan_purchases AS (
SELECT Cust_ID, MIN(Order_Date) AS first_purchase_date
FROM e_commerce_data
WHERE YEAR(Order_Date) = 2011 AND MONTH(Order_Date) = 1
GROUP BY Cust_ID
)
SELECT
DATEPART(month, Order_Date) AS order_month,
COUNT(DISTINCT jan_purchases.Cust_ID) AS customer_count
FROM jan_purchases
LEFT JOIN e_commerce_data
ON jan_purchases.Cust_ID = e_commerce_data.Cust_ID
AND YEAR(e_commerce_data.Order_Date) = 2011
AND Order_Date >= jan_purchases.first_purchase_date
GROUP BY DATEPART(month, Order_Date)
ORDER BY DATEPART(month, Order_Date)

---1.4. Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID.

WITH customer_orders AS (
  SELECT Cust_ID, Order_Date,
         ROW_NUMBER() OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS purchase_number
  FROM e_commerce_data
)
SELECT Cust_ID, 
       DATEDIFF(day, 
                (SELECT Order_Date FROM customer_orders
                 WHERE purchase_number = 1 AND customer_orders.Cust_ID = co.Cust_ID), 
                (SELECT Order_Date FROM customer_orders
                 WHERE purchase_number = 3 AND customer_orders.Cust_ID = co.Cust_ID)
               ) AS time_elapsed
FROM customer_orders co
WHERE purchase_number = 3
ORDER BY Cust_ID


---1.5. Write a query that returns customers who purchased both product 11 and product 14, as well as the ratio of these products to the total number of products purchased by the customer.

SELECT Cust_ID, 
    COUNT(DISTINCT Prod_ID) as Total_Products,
    COUNT(CASE WHEN Prod_ID = 'Prod_11' OR Prod_ID = 'Prod_14' THEN 1 END) as Products_11_14,
    COUNT(CASE WHEN Prod_ID = 'Prod_11' OR Prod_ID = 'Prod_14' THEN 1 END) * 1.0 / COUNT(DISTINCT Prod_ID) as Ratio
FROM e_commerce_data
WHERE Prod_ID IN ('Prod_11', 'Prod_14')
GROUP BY Cust_ID
HAVING COUNT(CASE WHEN Prod_ID = 'Prod_11' THEN 1 END) > 0 AND COUNT(CASE WHEN Prod_ID = 'Prod_14' THEN 1 END) > 0
ORDER BY Cust_ID;


---- 2. Categorize customers based on their frequency of visits. The following steps will guide you. If you want, you can track your own way.

SELECT 
  Cust_ID,
  COUNT(Cust_ID) as Visits,
  CASE 
    WHEN COUNT(Cust_ID) <= 5 THEN 'Occasional'
    WHEN COUNT(Cust_ID) BETWEEN 6 AND 10 THEN 'Frequent'
    WHEN COUNT(Cust_ID) > 10 THEN 'Regular'
    ELSE 'Unknown'
  END as Visitor_Category
FROM e_commerce_data
GROUP BY Cust_ID
ORDER BY Visits DESC;

---2.1. Create a “view” that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)

CREATE OR ALTER VIEW customer_visit_logs AS
SELECT Cust_ID, Year(Order_Date) AS Year, Month(Order_Date) AS Month
FROM e_commerce_data
GROUP BY Cust_ID, Year(Order_Date), Month(Order_Date);


---2.2. Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning business)

CREATE OR ALTER VIEW monthly_visits AS
SELECT Cust_ID, Order_Date, Year(Order_Date) AS Year, Month(Order_Date) AS Month, COUNT(*) AS Visits
FROM e_commerce_data
GROUP BY Cust_ID, Order_Date, Year(Order_Date), Month(Order_Date);


---2.3. For each visit of customers, create the next month of the visit as a separate column.

SELECT DISTINCT Cust_ID, Year, Month,
LEAD(Month) OVER (PARTITION BY Cust_ID ORDER BY Year, Month) AS next_month
FROM monthly_visits
ORDER BY Cust_ID;

---2.4. Calculate the monthly time gap between two consecutive visits by each customer.
----------------------------------------
WITH CTE AS (
    SELECT DISTINCT Cust_ID, Order_Date, Year, Month,
    LEAD(Month) OVER (PARTITION BY Cust_ID ORDER BY Year, Month) AS next_month
    FROM monthly_visits
    WHERE LEAD(Month) OVER (PARTITION BY Cust_ID ORDER BY Year, Month) IS NOT NULL
    GROUP BY Cust_ID, [Order_Date], [Year], [Month]
)
SELECT
    *,
    DATEDIFF(MONTH, MONTH(Order_Date), next_month) gap
FROM CTE

---2.5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.


---3. Find month-by-month customer retention rate since the start of the business.

WITH 
first_purchases AS (
    SELECT Cust_ID, MIN(Order_Date) AS first_purchase_date
    FROM e_commerce_data
    GROUP BY Cust_ID
),
retention_cust AS (
    SELECT
        YEAR(first_purchase_date) AS first_purchase_year,
        MONTH(first_purchase_date) AS first_purchase_month,
        COUNT(DISTINCT first_purchases.Cust_ID) AS total_customers,
        COUNT(DISTINCT second_purchases.Cust_ID) AS retained_customers 
    FROM first_purchases
    LEFT JOIN e_commerce_data AS second_purchases
        ON first_purchases.Cust_ID = second_purchases.Cust_ID
        AND second_purchases.Order_Date BETWEEN first_purchases.first_purchase_date AND DATEADD(month, 1, first_purchases.first_purchase_date)
    GROUP BY
       MONTH(first_purchase_date),
       YEAR(first_purchase_date)
)
SELECT
    first_purchase_year,
    first_purchase_month,
    total_customers,
    retained_customers,
    retained_customers / total_customers AS retention_rate
FROM
    retention_cust
ORDER BY first_purchase_year, first_purchase_month;



---3.1. Find the number of customers retained month-wise. (You can use time gaps)

WITH customer_visits AS (
    SELECT Cust_ID, Order_Date,
        ROW_NUMBER() OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS visit_number
    FROM e_commerce_data
),
time_gaps AS (
    SELECT 
        a.Cust_ID, 
        DATEDIFF(month, a.Order_Date, b.Order_Date) as time_gap
    FROM customer_visits a
    JOIN customer_visits b
    ON a.Cust_ID = b.Cust_ID AND a.visit_number = b.visit_number - 1
)
SELECT 
    MONTH(Order_Date) as month,
    COUNT(DISTINCT time_gaps.Cust_ID) as retained_customers
FROM customer_visits 
JOIN time_gaps
ON customer_visits.Cust_ID = time_gaps.Cust_ID
GROUP BY MONTH(Order_Date)
ORDER BY month;


---3.2.Calculate the month-wise retention rate.


WITH customer_visits AS (
    SELECT 
        Cust_ID, 
        Year(Order_Date) AS Year, 
        Month(Order_Date) AS Month,
        COUNT(DISTINCT Order_Date) AS Visits
    FROM e_commerce_data
    GROUP BY Cust_ID, Year(Order_Date), Month(Order_Date)
),
monthly_retention AS (
    SELECT 
        Year,
        Month,
        COUNT(Cust_ID) AS Total_Customers,
        COUNT(CASE WHEN Visits > 1 THEN 1 ELSE NULL END) AS Retained_Customers
    FROM customer_visits
    GROUP BY Year, Month
)
SELECT 
    Year,
    Month,
   -- Retained_Customers / Total_Customers AS Retention_Rate
	(Total_Customers  - (Total_Customers  - Retained_Customers )) / 100   AS Retention_Rate
FROM monthly_retention
ORDER BY Year, Month;










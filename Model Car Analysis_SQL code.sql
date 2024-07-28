--Question 1: Which Products Should We Order More of or Less of?
with low_stock as
(
    SELECT p.productCode,
           (SUM(quantityOrdered)/quantityInStock) stock
    FROM   orderdetails od
    JOIN   products p ON od.productCode=p.productCode
    GROUP BY p.productCode
    ORDER BY stock DESC
    LIMIT  10
)
SELECT p.productCode, p.productName, p.productLine,
       (SUM(quantityOrdered*priceEach)) perf
FROM   orderdetails od
JOIN   products p ON od.productCode=p.productCode
WHERE  p.productCode IN (SELECT productCode FROM low_stock)
GROUP BY p.productCode
--Question 2: How Should We Match Marketing and Communication Strategies to Customer Behavior?
--Compute how much profit each customer generates
SELECT customerNumber, SUM(od.quantityOrdered)*(od.priceEach-p.buyPrice) profit
FROM orderdetails od
JOIN products p ON od.productCode=p.productCode
JOIN orders o ON od.orderNumber=o.orderNumber
GROUP BY customerNumber
--Finding the VIP (very important person) customers and those who are less engaged
WITH profit_per_customer AS
(
    SELECT o.customerNumber, SUM(quantityOrdered * (priceEach - buyPrice)) AS profit
      FROM products p
      JOIN orderdetails od
        ON p.productCode = od.productCode
      JOIN orders o
        ON o.orderNumber = od.orderNumber
     GROUP BY o.customerNumber
)
SELECT contactLastName, contactFirstName, city, country, profit
FROM customers c
JOIN profit_per_customer pc ON c.customerNumber=pc.customerNumber
ORDER BY profit DESC
LIMIT 5


--Question 3: How Much Can We Spend on Acquiring New Customers?
--Find the number of new customers arriving each month
WITH 
payment_with_year_month_table AS (
SELECT *, 
       CAST(SUBSTR(paymentDate, 1,4) AS INTEGER)*100 + CAST(SUBSTR(paymentDate, 6,7) AS INTEGER) AS year_month
  FROM payments p
),
customers_by_month_table AS (
SELECT p1.year_month, COUNT(*) AS number_of_customers, SUM(p1.amount) AS total
  FROM payment_with_year_month_table p1
 GROUP BY p1.year_month
),
new_customers_by_month_table AS (
SELECT p1.year_month, 
       COUNT(DISTINCT customerNumber) AS number_of_new_customers,
       SUM(p1.amount) AS new_customer_total,
       (SELECT number_of_customers
          FROM customers_by_month_table c
        WHERE c.year_month = p1.year_month) AS number_of_customers,
       (SELECT total
          FROM customers_by_month_table c
         WHERE c.year_month = p1.year_month) AS total
  FROM payment_with_year_month_table p1
 WHERE p1.customerNumber NOT IN (SELECT customerNumber
                                   FROM payment_with_year_month_table p2
                                  WHERE p2.year_month < p1.year_month)
 GROUP BY p1.year_month
)
SELECT year_month, 
       ROUND(number_of_new_customers*100/number_of_customers,1) AS number_of_new_customers_props,
       ROUND(new_customer_total*100/total,1) AS new_customers_total_props
  FROM new_customers_by_month_table;
--Compute the Customer Lifetime Value (LTV), which represents the average amount of money a customer generates
WITH 
money_in_by_customer_table AS (
    SELECT o.customerNumber, ROUND(SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)), 2) profit
    FROM orders AS o
    JOIN orderdetails AS od ON o.orderNumber = od.orderNumber
    JOIN products AS p ON od.productCode = p.productCode
    GROUP BY o.customerNumber
    ORDER BY profit DESC
    )
    
SELECT ROUND(AVG(mc.profit), 2) AS ltv
  FROM money_in_by_customer_table AS mc

--1. update column name
UPDATE products
SET product_category_name =
(SELECT product_category_name_english FROM translation_name
 WHERE translation_name.product_category_name = products.product_category_name)

 --2. Top 10 sales product
SELECT product_category_name, ROUND(SUM(price)::NUMERIC,2) AS price
FROM products
JOIN order_items USING(product_id)
GROUP BY 1
ORDER BY price DESC
LIMIT 10

--3.Top 10 products for each year

WITH cte AS(
SELECT LEFT(order_delivered_carrier_date,4) AS year ,product_category_name, ROUND(SUM(price)::NUMERIC,2) AS price
FROM products
JOIN order_items USING(product_id)
LEFT JOIN orders ON order_items.order_id = orders.order_id
GROUP BY 1,2
ORDER BY price DESC),

cte2 AS(SELECT year, product_category_name, price, RANK() OVER (PARTITION BY year ORDER BY price DESC) AS ranking
FROM cte)

SELECT year, product_category_name, price
FROM cte2
WHERE ranking <= 10
ORDER BY year ASC, price DESC;

--4. Which day of the week, customers tend to go shopping?

SELECT extract(isodow from TO_DATE(order_purchase_timestamp,'YYYY/MM/DD')) AS day_of_week,
COUNT(order_id) AS num_order
FROM orders
GROUP BY 1

--5. What are the top 3 products for each state?

WITH order_products AS(SELECT order_id, price,product_category_name FROM order_items
JOIN products USING(product_id)),

state_total AS(SELECT customer_state, product_category_name, SUM(price) as total
FROM order_products
JOIN orders USING(order_id)
JOIN customers ON orders.customer_id = customers.customer_id
GROUP BY 1,2),

state_ranking AS(SELECT customer_state,product_category_name, total, RANK() OVER (PARTITION BY customer_state ORDER BY total DESC)
FROM state_total)

SELECT customer_state AS state, product_category_name, ROUND(total::numeric,2) AS total_sales
FROM state_ranking
WHERE rank <= 3


--6. What is the number of monthly active users for 2017? What is the MoM growth rate? What is the retention rate?

--6.1 monthly active users for 2017& (MoM) MAU growth rate
SELECT LEFT(order_purchase_timestamp,7) AS month, COUNT(DISTINCT customer_id)
FROM orders
WHERE LEFT(order_purchase_timestamp,4) = '2017'
GROUP BY 1

SELECT payment_type, COUNT(payment_type) AS num FROM order_payments
GROUP BY 1
ORDER BY num DESC
--6.2 retention rate

WITH monthly_customer AS (SELECT DISTINCT TO_TIMESTAMP(order_purchase_timestamp,'YYYY MM') AS order_month , customer_id
FROM orders)

SELECT
previous_month.order_month,
COUNT(DISTINCT this_month.customer_id::NUMERIC) / GREATEST(COUNT (DISTINCT previous_month.customer_id),1)
FROM monthly_customer AS previous_month
LEFT JOIN monthly_customer AS this_month
ON previous_month.customer_id = this_month.customer_id
AND previous_month.order_month = (this_month.order_month - INTERVAL '1 month')
GROUP BY 1


--7. What is the most popular payment method?

SELECT payment_type, COUNT(payment_type) AS num FROM order_payments
GROUP BY 1
ORDER BY num DESC


--8. Sales bin

WITH order_value AS (SELECT o.order_id, payment_value
FROM orders o
JOIN order_payments p USING(order_id))

SELECT ROUND(payment_value::NUMERIC,-2) AS value_100,COUNT(order_id)
FROM order_value
GROUP BY value_100
ORDER BY value_100


--9. Average review being answered time
SELECT extract(epoch from AVG(TO_TIMESTAMP(review_creation_date, 'YYYY/MM/DD/HH24:MI') - TO_TIMESTAMP(review_answer_timestamp, 'YYYY/MM/DD/HH24:MI'))) / 3600.00 as hours
FROM order_reviews


--10 Distribution for sales
WITH order_payment AS (SELECT o.order_id, payment_value
FROM orders o
JOIN order_payments p USING(order_id))

SELECT
ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY payment_value ASC ) :: NUMERIC,2) AS payment_p25,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY payment_value ASC ) :: NUMERIC,2) AS payment_p50,
ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY payment_value ASC ) :: NUMERIC,2) AS payment_p75,
ROUND(AVG(payment_value)::NUMERIC,2) AS avg_payment
FROM order_payment






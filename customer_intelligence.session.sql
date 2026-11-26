
SELECT count(*) FROM marts.customer_rfm;
--  row count per table 
SELECT 'customers' AS tbl, count(*) FROM staging.customers
UNION ALL SELECT 'orders', count(*) FROM staging.orders
UNION ALL SELECT 'order_items', count(*) FROM staging.order_items
UNION ALL SELECT 'order_payments', count(*) FROM staging.order_payments
UNION ALL SELECT 'order_reviews', count(*) FROM staging.order_reviews
UNION ALL SELECT 'products', count(*) FROM staging.products
UNION ALL SELECT 'sellers', count(*) FROM staging.sellers;

--data range of the data 

SELECT min(purchased_at)::date AS first_order,
       max(purchased_at)::date AS last_order,
       count(DISTINCT customer_unique_id) AS unique_customers
FROM marts.orders_enriched;

-- order by status 
SELECT order_status, count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM staging.orders
GROUP BY order_status ORDER BY orders DESC;
-- missing values in ordes (showing why some dates are empty )
SELECT count(*) AS total,
       count(*) FILTER (WHERE approved_at IS NULL)  AS no_approval,
       count(*) FILTER (WHERE shipped_at IS NULL)   AS no_shipping,
       count(*) FILTER (WHERE delivered_at IS NULL) AS no_delivery
FROM staging.orders;
-- monthly order by revenue 

SELECT date_trunc('month', purchased_at)::date AS month,
       count(*) AS orders,
       round(sum(payment_total)) AS revenue,
       round(avg(payment_total), 2) AS avg_order_value
FROM marts.orders_enriched
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1 ORDER BY 1;

--order by the day of the week 

SELECT to_char(purchased_at, 'Dy') AS weekday,
       extract(hour FROM purchased_at) AS hour,
       count(*) AS orders
FROM marts.orders_enriched
GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 15;

--where customere live 
SELECT state ,count(*) AS customers,
        round(100.0 * count(*)/ sum(count(*)) OVER(),1) AS pct
        FROM staging.customers
        GROUP  BY state ORDER BY customers DESC LIMIT 15;

--how many orders per customer 
SELECT frequency AS orders_placed , count(*) AS customer
FROM marts.customer_rfm
GROUP BY 1 order by 1;
--sped distribution (is revenue concentration in a few customer?)
SELECT ntile AS spend_decile,
       count(*) AS customers,
       round(sum(monetary)) AS revenue,
       round(100.0 * sum(monetary) / sum(sum(monetary)) OVER (), 1) AS pct_revenue
FROM (SELECT monetary, ntile(10) OVER (ORDER BY monetary DESC) AS ntile
      FROM marts.customer_rfm) t
GROUP BY ntile ORDER BY ntile;
--Top categories by revenue 
SELECT p.category,
       count(*) AS items_sold,
       round(sum(i.price)) AS revenue,
       round(avg(i.price), 2) AS avg_price
FROM staging.order_items i
JOIN staging.products p USING (product_id)
GROUP BY p.category ORDER BY revenue DESC LIMIT 10;
--seller concentration 
SELECT seller_id, count(DISTINCT order_id) AS orders, round(sum(price)) AS revenue
FROM staging.order_items
GROUP BY seller_id ORDER BY revenue DESC LIMIT 10;
--payment 
SELECT payment_type, count(*) AS payments,
       round(avg(payment_value), 2) AS avg_value,
       round(avg(installments), 1) AS avg_installments
FROM staging.order_payments
GROUP BY payment_type ORDER BY payments DESC;
--delivery time and latness
SELECT round(avg(extract(epoch FROM delivered_at - purchased_at) / 86400)::numeric, 1) AS avg_days_to_deliver,
       round(100.0 * avg(delivered_late::int), 1) AS pct_late
FROM marts.orders_enriched
WHERE order_status = 'delivered';
--reviews distribution 
SELECT review_score, count(*) AS reviews,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM staging.order_reviews
GROUP BY review_score ORDER BY review_score;
--does late delivery lower the review score 
SELECT delivered_late, count(*) AS orders, round(avg(review_score), 2) AS avg_score
FROM marts.orders_enriched
WHERE order_status = 'delivered' AND delivered_late IS NOT NULL
GROUP BY delivered_late;
--orders with no items or payment 
SELECT count(*) FILTER (WHERE items = 0)         AS orders_without_items,
       count(*) FILTER (WHERE payment_total = 0) AS orders_without_payment
FROM marts.orders_enriched;
--duplicates that should not exist 
SELECT order_id FROM staging.orders GROUP BY order_id HAVING count(*) > 1;
SELECT customer_unique_id FROM marts.customer_rfm GROUP BY 1 HAVING count(*) > 1;

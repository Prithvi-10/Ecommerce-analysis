-- 1._____________________________________ Customers_dataset Table_______________________________________________

SELECT * FROM raw_customers_dataset;

DESCRIBE raw_customers_dataset;
SELECT COUNT(*) FROM raw_customers_dataset;

CREATE TABLE customers_dataset
(
customer_id varchar (50) PRIMARY KEY,                              -- Creating a table with correct datatype
customer_unique_id varchar (50) ,
customer_zip_code_prefix VARCHAR (10),
customer_city varchar (50),
customer_state char(2)
)

INSERT INTO customers_dataset
(
customer_id ,
customer_unique_id  ,
customer_zip_code_prefix ,                                		-- Inserting Data to New table (slightly cleaning while inserting) 
customer_city ,
customer_state 
)
SELECT 
TRIM(customer_id ),
TRIM(customer_unique_id  ),
TRIM(customer_zip_code_prefix ),
TRIM(customer_city) ,
TRIM(customer_state) 
FROM raw_customers_dataset;

SELECT COUNT(*) FROM customers_dataset;

-- Checking is there anything else to clean

SELECT * FROM customers_dataset;

SELECT DISTINCT customer_city FROM customers_dataset ORDER BY 1 ;
SELECT DISTINCT customer_state FROM customers_dataset ORDER BY 1 ;

SELECT * FROM customers_dataset WHERE customer_state IS NULL; 


-- 2._____________________________________ Geolocation_dataset Table _______________________________________________

SELECT * FROM raw_geolocation_dataset;

CREATE TABLE geolocation_dataset
(
id INT AUTO_INCREMENT PRIMARY KEY,
geolocation_zip_code_prefix VARCHAR (10),
geolocation_lat DOUBLE ,                              -- Creating a table with correct datatype
geolocation_lng DOUBLE ,

geolocation_city varchar (100),
geolocation_state char(2)
);

INSERT INTO geolocation_dataset
(

geolocation_zip_code_prefix ,
geolocation_lat  ,                               
geolocation_lng  ,

geolocation_city  ,
geolocation_state 
)
SELECT 
TRIM(geolocation_zip_code_prefix  ),
geolocation_lat ,                                        -- Inserting Data to New table (slightly cleaning while inserting) 
geolocation_lng,
LOWER(TRIM(geolocation_city)) ,
UPPER(TRIM(geolocation_state) )
FROM raw_geolocation_dataset;

SELECT COUNT(*) FROM raw_geolocation_dataset;
SELECT COUNT(*) FROM geolocation_dataset;

SELECT * FROM geolocation_dataset 
WHERE geolocation_zip_code_prefix IS NULL                    -- Checking NULL
OR geolocation_lat IS NULL
OR geolocation_lng IS NULL;


  --   Cleaning City data


SELECT 
    geolocation_zip_code_prefix,
    LOWER(TRIM(geolocation_city)) AS city_raw,                      -- Grouping by zip and seeing duplicates but with different characters
    COUNT(*) AS occurrences
FROM geolocation_dataset
GROUP BY 1, 2
ORDER BY geolocation_zip_code_prefix, occurrences DESC;

SELECT 
    geolocation_city,
    COUNT(*) AS occurrences										-- Variants of sao paulo
FROM geolocation_dataset
WHERE geolocation_city LIKE '%paulo%'
GROUP BY geolocation_city;

UPDATE geolocation_dataset
SET geolocation_city = 'sao paulo'
WHERE geolocation_city LIKE '%paulo%';                              -- Updating all variants to sao paulo


SELECT * FROM geolocation_dataset;

SELECT 
    geolocation_zip_code_prefix,
    LOWER(TRIM(geolocation_city)) AS city_raw,                      -- Other cities than sao paulo
    COUNT(*) AS occurrences 										-- Found sp on city
FROM geolocation_dataset											-- Found two cities with encoding issue
WHERE geolocation_city NOT LIKE 'sao paulo'
GROUP BY 1, 2
ORDER BY geolocation_zip_code_prefix, occurrences DESC;

SELECT * 
FROM geolocation_dataset 
WHERE geolocation_city = 'sp';

UPDATE geolocation_dataset
SET geolocation_city = NULL
WHERE geolocation_city = 'sp';

UPDATE geolocation_dataset
SET geolocation_city = 'jundiai'
WHERE geolocation_city = 'jundiaã­';

UPDATE geolocation_dataset
SET geolocation_city = 'taboao da serra'
WHERE geolocation_city = 'taboã£o da serra';


-- Cleaning lat and lng


SELECT 
    geolocation_zip_code_prefix,
    COUNT(*)                            AS total_rows,
    COUNT(DISTINCT geolocation_lat)     AS unique_lats,
    COUNT(DISTINCT geolocation_lng)     AS unique_lngs,							-- Zips that have more than one unique lat/lng combination
    AVG(geolocation_lat) 				AS avg_lat,
    AVG(geolocation_lng)				AS avg_lng
FROM geolocation_dataset
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(DISTINCT geolocation_lat) > 1   -- only zips with different lats
ORDER BY unique_lats DESC;

SELECT * FROM(
SELECT *,
ROW_NUMBER() 																			-- Finding exact duplciates
OVER(
PARTITION BY geolocation_zip_code_prefix,geolocation_lat,geolocation_lng,geolocation_city,geolocation_state
) AS row_num
FROM geolocation_dataset) as x
WHERE row_num > 1;

DELETE 
FROM geolocation_dataset
WHERE id IN
(
SELECT id FROM(
SELECT id,																		-- Deleting exact duplciates
ROW_NUMBER() 
OVER(
PARTITION BY geolocation_zip_code_prefix,geolocation_lat,geolocation_lng,geolocation_city,geolocation_state
) AS row_num
FROM geolocation_dataset) as x
WHERE row_num > 1
);

SELECT count(geolocation_zip_code_prefix) FROM geolocation_dataset;

SELECT COUNT(DISTINCT geolocation_zip_code_prefix) FROM geolocation_dataset;

SELECT 
    geolocation_zip_code_prefix,
    COUNT(*) AS row_count
FROM geolocation_dataset												-- Zips that have more than one unique lat/lng combination
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1
ORDER BY row_count DESC;


-- Creating another table which will have one zip = one row


CREATE TABLE geolocation_dataset_final AS 
SELECT
	geolocation_zip_code_prefix ,
	AVG(geolocation_lat) AS  geolocation_lat ,                              -- Creating a table with one zip with almost one unique lat and long
	AVG(geolocation_lng) AS  geolocation_lng ,   
	MAX(geolocation_city) AS geolocation_city ,
	geolocation_state 
FROM geolocation_dataset
GROUP BY geolocation_zip_code_prefix, geolocation_state;
  

SELECT * 
FROM geolocation_dataset_final
WHERE geolocation_zip_code_prefix IN                                              -- Checking the Zip with more than 1 row
(
SELECT geolocation_zip_code_prefix
FROM geolocation_dataset_final
GROUP BY geolocation_zip_code_prefix 
HAVING count(*) > 1
);

SELECT * FROM 
(
SELECT geolocation_zip_code_prefix,geolocation_state              -- Finding the zip which we want to delete
FROM geolocation_dataset_final
GROUP BY geolocation_zip_code_prefix,geolocation_state

) x
WHERE geolocation_state != 'SP';

START TRANSACTION;

SELECT *
FROM geolocation_dataset_final												-- Data we want to delete
WHERE 
geolocation_zip_code_prefix IN ('02116','04011')
AND 
geolocation_state != 'SP';
    
DELETE FROM geolocation_dataset_final
WHERE 
geolocation_zip_code_prefix IN ('02116','04011')							-- Deleting those rows
AND 
geolocation_state != 'SP';

COMMIT;


-- _________________________________________________ 3. Order_items_dataset Table _____________________________________________________________


SELECT * FROM raw_order_items_dataset;

CREATE TABLE order_items_dataset
(
	id INT AUTO_INCREMENT PRIMARY KEY,
	order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),                                             -- Creating a new partially cleaned table
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);

INSERT INTO order_items_dataset
(
	order_id ,
    order_item_id ,
    product_id ,
    seller_id ,
    shipping_limit_date ,
    price ,
    freight_value 
)
SELECT 
                                                                        -- Inserting data into table
	TRIM(order_id) ,
    order_item_id,
    TRIM(product_id) ,
    TRIM(seller_id) ,
    shipping_limit_date ,
    price ,
    freight_value
 FROM raw_order_items_dataset;
 
 SELECT count(*) FROM raw_order_items_dataset;                         -- confirming count is same
 SELECT count(*) FROM order_items_dataset;
 
 
 -- NUll check 
 
 SELECT * FROM order_items_dataset
 WHERE order_id IS NULL 
 OR order_item_id IS NULL 
 OR product_id IS NULL 
 OR seller_id IS NULL 
 OR shipping_limit_date IS NULL 
 OR price IS NULL 
 OR freight_value IS NULL;
 
 -- Duplicate check
 
 SELECT * FROM 
 (
 SELECT * , ROW_NUMBER()
 OVER(PARTITION BY order_id,order_item_id) as rnk 
 FROM order_items_dataset
) o
 HAVING rnk > 1;
 
 SELECT * FROM order_items_dataset;
 
 
 -- _________________________________________________ 4. Order_payments_dataset Table _____________________________________________________________
 
 
 SELECT * FROM raw_order_payments_dataset;
 
 CREATE TABLE order_payments_dataset
 (
    id INT AUTO_INCREMENT PRIMARY KEY,
	order_id VARCHAR(50),
    payment_sequential INT,														 -- Creating a new partially cleaned table
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);

INSERT INTO order_payments_dataset
 (
	order_id ,
    payment_sequential ,
    payment_type ,
    payment_installments ,
    payment_value 
)
SELECT 
	TRIM(order_id) ,																	-- Inserting data into table
    payment_sequential ,
    payment_type ,
    payment_installments ,
    payment_value 
FROM raw_order_payments_dataset;

DROP TABLE order_payments_dataset;

SELECT count(*) FROM raw_order_payments_dataset;								-- Confirming count is same
SELECT count(*) FROM order_payments_dataset;

-- NUll check 
 
 SELECT * FROM order_payments_dataset
 WHERE order_id IS NULL 
 OR payment_value IS NULL 
 OR payment_type IS NULL;
 
 -- Duplicate check
 
 SELECT * FROM 
 (
 SELECT * , ROW_NUMBER()
 OVER(PARTITION BY order_id,payment_sequential) as rnk 
 FROM order_payments_dataset
) o
 HAVING rnk > 1;
 
 
 -- values check 
 
SELECT * 
 FROM order_payments_dataset                                 -- Found some with value 0 
 WHERE payment_value <= 0;
 
SELECT * 
 FROM order_payments_dataset
 WHERE payment_installments <= 0;
 
SELECT payment_type, COUNT(*)
FROM order_payments_dataset
GROUP BY payment_type;


START TRANSACTION;

UPDATE order_payments_dataset
SET payment_type = "unknown"                                   -- updating rows with value 0 and payment_type not defined
WHERE payment_type = 'not_defined';

SELECT payment_type, COUNT(*)
FROM order_payments_dataset
GROUP BY payment_type;

COMMIT;


-- Checking whether payment value of order from this table is equal to value from order table

SELECT sp.order_id, sp.total_payment, so.total_order_value FROM
(
SELECT order_id, SUM(payment_value) AS total_payment
FROM order_payments_dataset
GROUP by order_id
) sp
JOIN
(
SELECT order_id, SUM(price + freight_value) AS total_order_value
FROM order_items_dataset
GROUP by order_id
) so
ON sp.order_id = so.order_id;


-- Finding data where both the sums are not equal

WITH mismatched_orders AS
(
SELECT order_id, total_payment,total_order_value,ABS(total_payment - total_order_value) AS difference 
FROM
(
SELECT sp.order_id, sp.total_payment, so.total_order_value FROM
(
SELECT order_id, SUM(payment_value) AS total_payment
FROM order_payments_dataset
GROUP by order_id
) sp
JOIN
(
SELECT order_id, SUM(price + freight_value) AS total_order_value
FROM order_items_dataset
GROUP by order_id
) so
ON sp.order_id = so.order_id
) x
WHERE  ABS(total_payment - total_order_value) > 0.01
)

SELECT op.order_id,
	   op.payment_value,
       op.payment_type,
       mo.difference,
       mo.total_order_value,
       mo.total_payment
FROM mismatched_orders mo
JOIN order_payments_dataset op
ON mo.order_id = op.order_id;



 -- _________________________________________________ 5. Order_reviews_dataset Table _____________________________________________________________

SELECT * FROM raw_order_reviews_dataset;

CREATE TABLE order_reviews_dataset
(
 id INT AUTO_INCREMENT PRIMARY KEY,
 review_id VARCHAR(50),
 order_id VARCHAR(50),
 review_score INT,
 review_comment_title VARCHAR(100),
 review_comment_message TEXT,
 review_creation_date DATETIME,
 review_answer_timestamp DATETIME
 );
 
 INSERT INTO order_reviews_dataset
 (
 review_id ,
 order_id , 
 review_score ,
 review_comment_title ,
 review_comment_message ,
 review_creation_date ,
 review_answer_timestamp 
 )
 SELECT
 TRIM(review_id) ,
 TRIM(order_id) , 
 review_score ,
 review_comment_title ,
 review_comment_message ,
 review_creation_date ,
 review_answer_timestamp 
 FROM raw_order_reviews_dataset;
 
 
 SELECT count(*) FROM raw_order_reviews_dataset;
 SELECT count(*) FROM order_reviews_dataset;
 
 -- Null check
 
 SELECT * 
 FROM order_reviews_dataset
 WHERE review_id IS NULL
 OR order_id IS NULL
 OR review_creation_date IS NULL
 OR review_score IS NULL;
 
 -- Duplicate check
 
 SELECT review_id , count(*) 
 FROM order_reviews_dataset
 GROUP BY review_id
 HAVING count(*) > 1;
 
 
 -- Review score check 
 
 SELECT * 
 FROM order_reviews_dataset
WHERE review_score < 1 OR review_score > 5;
 
 -- Checking where review answer time less than review creation time
 
SELECT * 
FROM order_reviews_dataset
WHERE review_answer_timestamp < review_creation_date ;

 
 
 -- _________________________________________________ 6. Order_dataset Table _____________________________________________________________
 
 
 SELECT * FROM raw_orders_dataset;
 
 
 CREATE TABLE orders_dataset
 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id VARCHAR(50),
  customer_id VARCHAR(50),
  order_status VARCHAR(20),
  order_purchase_timestamp DATETIME,
  order_approved_at DATETIME,
  order_delivered_carrier_date DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME
  );
  
  INSERT INTO orders_dataset
  (
  order_id ,
  customer_id ,
  order_status ,
  order_purchase_timestamp ,
  order_approved_at ,         
  order_delivered_carrier_date ,
  order_delivered_customer_date ,
  order_estimated_delivery_date 
  )
  SELECT 
  TRIM(order_id) ,
  TRIM(customer_id) ,
  TRIM(order_status) ,                    
  NULLIF(order_purchase_timestamp , ''),							-- NULLIF to convert empty string to null
  NULLIF(order_approved_at , ''),
  NULLIF(order_delivered_carrier_date , ''),
  NULLIF(order_delivered_customer_date , '') ,
  NULLIF(order_estimated_delivery_date , '')
  FROM raw_orders_dataset;
  
  
  -- check number of rows is equal
  
SELECT count(*) FROM raw_orders_dataset;
SELECT count(*) FROM orders_dataset;

-- NULL values

SELECT * 
FROM orders_dataset
WHERE order_id IS NULL
OR order_status IS NULL;

-- Exact duplicate values check 

SELECT o1.*  
FROM orders_dataset o1
JOIN
(	SELECT order_id,count(*)
	FROM orders_dataset o2
    GROUP BY order_id
    HAVING count(*) > 1
) o2
ON o1.order_id = o2.order_id;


SELECT * FROM orders_dataset;

-- Date mismatch

SELECT * 
FROM orders_dataset
WHERE order_purchase_timestamp > order_approved_at;

SELECT * 
FROM orders_dataset                                                               -- Found mismatch
WHERE order_delivered_carrier_date > order_delivered_customer_date;


START TRANSACTION;

UPDATE orders_dataset
SET order_delivered_carrier_date = NULL
WHERE order_delivered_carrier_date > order_delivered_customer_date;

SELECT * 
FROM orders_dataset                                                               -- Rechecking
WHERE order_delivered_carrier_date > order_delivered_customer_date;

COMMIT;

SELECT * 
FROM orders_dataset                                                               
WHERE order_delivered_customer_date < order_purchase_timestamp ;

SELECT * 
FROM orders_dataset                                                               
WHERE order_estimated_delivery_date < order_purchase_timestamp ;



 -- _________________________________________________ 7. Product Category Name Table _____________________________________________________________


SELECT * FROM raw_product_category_name_translation;

CREATE TABLE product_category_name_translation
(
product_category_name VARCHAR(50),
product_category_name_english VARCHAR(50)
);

INSERT INTO product_category_name_translation
(
product_category_name,
product_category_name_english
)
SELECT 
TRIM(`ï»¿product_category_name`),
TRIM(product_category_name_english)
FROM raw_product_category_name_translation;


-- check number of rows is equal
  
SELECT count(*) FROM raw_product_category_name_translation;
SELECT count(*) FROM product_category_name_translation;

-- NULL values

SELECT * 
FROM product_category_name_translation
WHERE product_category_name IS NULL
OR product_category_name_english IS NULL;

-- Exact duplicate values check 

SELECT product_category_name
FROM product_category_name_translation
GROUP BY product_category_name
HAVING count(*) > 1;



 -- _________________________________________________ 8. Products Dataset Table _____________________________________________________________


SELECT * FROM raw_products_dataset;
SELECT LENGTH(product_category_name) FROM raw_products_dataset ORDER BY LENGTH(product_category_name) DESC;

CREATE TABLE products_dataset
(
 product_id VARCHAR(50),
 product_category_name VARCHAR(50),
 product_name_length INT,
 product_description_length INT,
 product_photos_qty INT,
 product_weight_g INT,
 product_length_cm INT,
 product_height_cm INT,
 product_width_cm INT
 );
 
 INSERT INTO products_dataset
 (
 product_id ,
 product_category_name ,
 product_name_length ,
 product_description_length ,
 product_photos_qty ,
 product_weight_g ,
 product_length_cm ,
 product_height_cm ,
 product_width_cm 
 )
 SELECT 
 TRIM(product_id) ,
 TRIM(product_category_name) ,
 product_name_lenght ,
 product_description_lenght  ,
 product_photos_qty ,
 product_weight_g ,
 product_length_cm ,
 product_height_cm ,
 product_width_cm 
 FROM raw_products_dataset;
 
 ALTER TABLE products_dataset
ADD PRIMARY KEY (product_id);
 
 -- check number of rows is equal
  
SELECT count(*) FROM raw_products_dataset;
SELECT count(*) FROM products_dataset;

-- NULL values

SELECT * 
FROM products_dataset
WHERE product_id IS NULL;

-- Exact duplicate values check 

SELECT product_id
FROM products_dataset
GROUP BY product_id
HAVING count(*) > 1;

-- checking dimensions

SELECT * FROM products_dataset;

SELECT * FROM products_dataset 
WHERE product_name_length < 0 
OR product_name_length > 100;

SELECT * FROM products_dataset 
WHERE product_description_length < 0 
OR product_description_length > 10000;

SELECT * FROM products_dataset 
WHERE product_weight_g <= 0 ;

UPDATE products_dataset
SET product_weight_g = NULL    						-- update 0 values to null
WHERE product_weight_g = 0;

SELECT * FROM products_dataset 						-- cross checking
WHERE product_weight_g IS NULL;

SELECT * FROM products_dataset 
WHERE product_length_cm <= 0 ;

SELECT * FROM products_dataset 
WHERE product_height_cm <= 0 ;

SELECT * FROM products_dataset 
WHERE product_width_cm <= 0 ;


 -- _________________________________________________ 9. Sellers Dataset Table _____________________________________________________________


SELECT * FROM raw_sellers_dataset;
SELECT LENGTH(seller_city) FROM raw_sellers_dataset ORDER BY LENGTH(seller_city) DESC;

CREATE TABLE sellers_dataset
(
 seller_id VARCHAR(50),
 seller_zip_code_prefix INT,
 seller_city VARCHAR(50),
 seller_state CHAR(2) 
 );
 
 INSERT INTO sellers_dataset
 (
 seller_id ,
 seller_zip_code_prefix ,
 seller_city ,
 seller_state  
 )
 SELECT 
	TRIM(seller_id) ,
	seller_zip_code_prefix ,
	TRIM(seller_city) ,
	TRIM(seller_state)
FROM raw_sellers_dataset;


 -- check number of rows is equal
  
SELECT count(*) FROM raw_sellers_dataset;
SELECT count(*) FROM sellers_dataset;

-- check city

SELECT seller_city,count(*)
FROM sellers_dataset
GROUP BY (seller_city);

SELECT seller_city,count(*)
FROM sellers_dataset
WHERE seller_city LIKE '%paulo%'
GROUP BY (seller_city);

-- Normalising city name

UPDATE sellers_dataset
SET seller_city =
LOWER(
    REPLACE(
        REPLACE(
            REPLACE(
                REPLACE(
                    TRIM(SUBSTRING_INDEX(seller_city, '/', 1)),
                '-', ' '),
            '  ', ' '),
        'ã', 'a'),
    'ç', 'c')
);






-- _________________________________________________________________ ANALYSIS ________________________________________________________________________________
 
 
 -- total revenue
 
SELECT  DATE_FORMAT(od.order_purchase_timestamp, '%Y-%m') AS order_month,
		COUNT(DISTINCT od.order_id) AS total_orders,
		SUM( oi.price  + oi.freight_value) AS Revenue,
       ( SUM( oi.price  + oi.freight_value) / COUNT( DISTINCT od.order_id) ) AS Avg_order_value
FROM 
	orders_dataset od 
JOIN 
	order_items_dataset oi
ON od.order_id = oi.order_id

GROUP BY order_month
ORDER BY order_month;
 

-- Customer satistfaction

SELECT  
    CASE 
        WHEN od.order_delivered_customer_date > od.order_estimated_delivery_date 
        THEN 'Delayed'
        ELSE 'On-time'
    END AS delivery_status,

    AVG(ore.review_score) AS avg_review_score

FROM orders_dataset od 

JOIN order_reviews_dataset ore
ON od.order_id = ore.order_id

GROUP BY delivery_status;



-- Which states generate the most revenue?
SELECT 
    c.customer_state,
    ROUND(SUM(oi.price + oi.freight_value), 2)  AS revenue,
    COUNT(DISTINCT o.order_id)                   AS total_orders
FROM orders_dataset o
JOIN order_items_dataset oi ON o.order_id = oi.order_id
JOIN customers_dataset c    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Payment method preference
SELECT 
    payment_type,
    COUNT(*)                        AS total_transactions,
    ROUND(SUM(payment_value), 2)    AS total_value,
    ROUND(AVG(payment_value), 2)    AS avg_value
FROM order_payments_dataset
WHERE payment_type != 'unknown'
GROUP BY payment_type
ORDER BY total_transactions DESC;
 
 
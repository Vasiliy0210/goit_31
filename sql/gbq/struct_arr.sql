select *
from goit.orders


-- ============================================
-- 1. IN UNNEST - Check if value exists in array
-- ============================================

-- Find orders that have 'tag-a' in any item
SELECT order_id, customer.user_id
FROM goit.orders, UNNEST(items) AS item
WHERE 'tag-a' IN UNNEST(item.tags);

-- Find orders with specific payment methods
SELECT order_id, settlement.currency
FROM goit.orders
WHERE 'card' IN UNNEST(
  ARRAY(SELECT payment.method FROM UNNEST(settlement.payments) AS payment)
);


-- ============================================
-- 2. EXISTS - Check if condition exists in array
-- ============================================

-- Find orders where any item quantity is greater than 2
SELECT order_id, customer.location.city
FROM goit.orders
WHERE EXISTS(
  SELECT 1 FROM UNNEST(items) AS item WHERE item.qty > 2
);

-- Find orders that reached 'shipped' status
SELECT order_id, order_ts
FROM goit.orders
WHERE EXISTS(
  SELECT 1 FROM UNNEST(status_history) AS status WHERE status.status = 'shipped'
);

-- ============================================
-- 3. ARRAY(SELECT FROM UNNEST) - Transform arrays
-- ============================================

-- Extract only SKUs from items array
SELECT 
  order_id,
  ARRAY(SELECT item.sku FROM UNNEST(items) AS item) AS skus
FROM goit.orders;

-- Get all status names as array
SELECT 
  order_id,
  ARRAY(SELECT status.status FROM UNNEST(status_history) AS status) AS statuses
FROM goit.orders;

-- Calculate total price per item and return as array
SELECT 
  order_id,
  ARRAY(
    SELECT item.qty * item.price 
    FROM UNNEST(items) AS item
  ) AS item_totals
FROM goit.orders;

-- Filter and transform: get only items with qty > 1
SELECT 
  order_id,
  ARRAY(
    SELECT STRUCT(item.sku AS sku, item.qty AS qty) 
    FROM UNNEST(items) AS item 
    WHERE item.qty > 1
  ) AS filtered_items
FROM goit.orders;


-- ============================================
-- 4. ARRAY_AGG - Aggregate values into array
-- ============================================

-- Aggregate all order IDs by user
SELECT 
  customer.user_id,
  ARRAY_AGG(order_id) AS user_orders
FROM goit.orders
GROUP BY customer.user_id;

-- Aggregate order dates by country
SELECT 
  customer.country,
  ARRAY_AGG(DATE(order_ts) ORDER BY order_ts) AS order_dates
FROM goit.orders
GROUP BY customer.country;

-- Create array of all SKUs across all orders (with duplicates)
SELECT 
  ARRAY_AGG(item.sku) AS all_skus
FROM goit.orders, UNNEST(items) AS item;

-- Create array of distinct SKUs with ordering
SELECT 
  ARRAY_AGG(DISTINCT item.sku ORDER BY item.sku) AS unique_skus
FROM goit.orders, UNNEST(items) AS item;

-- Aggregate payment amounts by user
SELECT 
  customer.user_id,
  ARRAY_AGG(payment.amount ORDER BY payment.amount DESC) AS payment_amounts
FROM goit.orders, UNNEST(settlement.payments) AS payment
GROUP BY customer.user_id;


-- ============================================
-- 5. CROSS JOIN UNNEST() WITH OFFSET
-- ============================================

-- Get items with their position in the array
SELECT 
  order_id,
  item_offset,
  item.sku,
  item.qty,
  item.price
FROM goit.orders
CROSS JOIN UNNEST(items) AS item WITH OFFSET AS item_offset
ORDER BY order_id, item_offset;

-- Get status history with position
SELECT 
  order_id,
  status_position,
  status.status,
  status.ts
FROM goit.orders
CROSS JOIN UNNEST(status_history) AS status WITH OFFSET AS status_position
ORDER BY order_id, status_position;

-- Find first and last items using offset
SELECT 
  order_id,
  item_offset,
  item.sku,
  CASE 
    WHEN item_offset = 0 THEN 'FIRST ITEM'
    ELSE 'OTHER ITEM'
  END AS position_label
FROM goit.orders
CROSS JOIN UNNEST(items) AS item WITH OFFSET AS item_offset;

-- Get tags with their positions within each item
SELECT 
  order_id,
  item_offset,
  item.sku,
  tag_offset,
  tag
FROM goit.orders
CROSS JOIN UNNEST(items) AS item WITH OFFSET AS item_offset
CROSS JOIN UNNEST(item.tags) AS tag WITH OFFSET AS tag_offset
ORDER BY order_id, item_offset, tag_offset;


-- ============================================
-- 6. ARRAY[OFFSET(n)] and ARRAY[SAFE_OFFSET(n)]
-- ============================================

-- Get first item from each order (errors if array is empty)
SELECT 
  order_id,
  items[OFFSET(3)].sku AS first_item_sku,
  items[OFFSET(3)].price AS first_item_price
FROM goit.orders;

-- Get second item if exists (returns NULL if doesn't exist)
SELECT 
  order_id,
  items[SAFE_OFFSET(0)].sku AS second_item_sku,
  items[SAFE_OFFSET(0)].qty AS second_item_qty
FROM goit.orders;

-- Get first and last status
SELECT 
  order_id,
  status_history[OFFSET(0)].status AS first_status,
  status_history[SAFE_OFFSET(2)].status AS last_status
FROM goit.orders;

-- Get specific payment method
SELECT 
  order_id,
  settlement.payments[OFFSET(0)].method AS first_payment_method,
  settlement.payments[OFFSET(0)].amount AS first_payment_amount,
  settlement.payments[SAFE_OFFSET(1)].method AS second_payment_method
FROM goit.orders;

-- Get first tag from first item
SELECT 
  order_id,
  items[OFFSET(0)].tags[OFFSET(0)] AS first_tag_of_first_item
FROM goit.orders;

-- Safe access to potentially missing elements
SELECT 
  order_id,
  items[SAFE_OFFSET(0)].sku AS item_1,
  items[SAFE_OFFSET(1)].sku AS item_2,
  items[SAFE_OFFSET(2)].sku AS item_3,
  items[SAFE_OFFSET(3)].sku AS item_4
FROM goit.orders;


-- ============================================
-- 7. ARRAY_LENGTH - Get size of array
-- ============================================

-- Count number of items in each order
SELECT 
  order_id,
  ARRAY_LENGTH(items) AS num_items,
  customer.user_id
FROM goit.orders;

-- Find orders with more than 2 items
SELECT 
  order_id,
  ARRAY_LENGTH(items) AS num_items
FROM goit.orders
WHERE ARRAY_LENGTH(items) > 2;

-- Count status changes
SELECT 
  order_id,
  ARRAY_LENGTH(status_history) AS num_status_changes
FROM goit.orders;

-- Count number of payment methods used
SELECT 
  order_id,
  ARRAY_LENGTH(settlement.payments) AS num_payment_methods,
  settlement.currency
FROM goit.orders;

-- Get length of tags array for each item
SELECT 
  order_id,
  item.sku,
  ARRAY_LENGTH(item.tags) AS num_tags
FROM goit.orders
CROSS JOIN UNNEST(items) AS item;

-- Compare array lengths
SELECT 
  order_id,
  ARRAY_LENGTH(items) AS items_count,
  ARRAY_LENGTH(status_history) AS status_count,
  ARRAY_LENGTH(settlement.payments) AS payment_count
FROM goit.orders;


-- ============================================
-- 8. CROSS JOIN UNNEST - Multiple examples
-- ============================================

-- Flatten items (basic usage)
SELECT 
  order_id,
  customer.user_id,
  item.sku,
  item.qty,
  item.price
FROM goit.orders
CROSS JOIN UNNEST(items) AS item;

-- Flatten multiple arrays - items and status_history
SELECT 
  order_id,
  item.sku,
  status.status,
  status.ts
FROM goit.orders
CROSS JOIN UNNEST(items) AS item
CROSS JOIN UNNEST(status_history) AS status;

-- Flatten nested arrays - items and their tags
SELECT 
  order_id,
  item.sku,
  tag
FROM goit.orders
CROSS JOIN UNNEST(items) AS item
CROSS JOIN UNNEST(item.tags) AS tag;

-- Flatten payments
SELECT 
  order_id,
  customer.location.city,
  payment.method,
  payment.amount
FROM goit.orders
CROSS JOIN UNNEST(settlement.payments) AS payment;

-- Calculate total order value by flattening items
SELECT 
  order_id,
  customer.user_id,
  SUM(item.qty * item.price) AS total_order_value
FROM goit.orders
CROSS JOIN UNNEST(items) AS item
GROUP BY order_id, customer.user_id;

-- LEFT JOIN UNNEST (keep orders even if array is empty)
SELECT 
  order_id,
  item.sku,
  item.price
FROM goit.orders
LEFT JOIN UNNEST(items) AS item;


-- ============================================
-- 9. COMBINED EXAMPLES - Multiple techniques
-- ============================================

-- Find orders with high-value items (qty * price > 20) using multiple techniques
SELECT 
  order_id,
  ARRAY_LENGTH(items) AS total_items,
  ARRAY(
    SELECT item.sku 
    FROM UNNEST(items) AS item 
    WHERE item.qty * item.price > 20
  ) AS high_value_skus
FROM goit.orders
WHERE EXISTS(
  SELECT 1 FROM UNNEST(items) AS item WHERE item.qty * item.price > 20
);

-- Get first item SKU and count of all items
SELECT 
  order_id,
  items[SAFE_OFFSET(0)].sku AS first_item,
  ARRAY_LENGTH(items) AS total_items,
  customer.user_id
FROM goit.orders;

-- Aggregate SKUs by user with ordering
SELECT 
  customer.user_id,
  ARRAY_AGG(item.sku ORDER BY item.price DESC) AS skus_by_price
FROM goit.orders
CROSS JOIN UNNEST(items) AS item
GROUP BY customer.user_id;

-- Find orders with 'shipped' status using IN UNNEST
SELECT 
  order_id,
  status_history[SAFE_OFFSET(0)].status AS initial_status,
  ARRAY_LENGTH(status_history) AS status_count
FROM goit.orders
WHERE 'shipped' IN UNNEST(
  ARRAY(SELECT s.status FROM UNNEST(status_history) AS s)
);
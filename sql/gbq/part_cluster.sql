-- ============================================
-- 1. QUERYING PARTITION METADATA
-- ============================================
select * from goit.orders
-- View all partitions in the orders table
SELECT
    partition_id,
    total_rows,
    total_logical_bytes,
    last_modified_time
FROM `goit.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'orders'
ORDER BY partition_id;

select *
from goit.orders
where DATE(order_ts) between  '2025-09-01' and CURRENT_DATE()

-- Get partition details with size information
SELECT
    partition_id,
    total_rows,
    ROUND(total_logical_bytes / 1024 / 1024, 2) AS size_mb,
    ROUND(total_billable_bytes / 1024 / 1024, 2) AS billable_mb
FROM `goit.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'orders'
  AND partition_id != '__NULL__'
ORDER BY partition_id DESC;

-- Check specific date partition
SELECT
    partition_id,
    total_rows
FROM `goit.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'orders'
  AND partition_id = FORMAT_DATE('%Y%m%d', CURRENT_DATE());


-- ============================================
-- 2. PARTITION PRUNING - Efficient queries
-- ============================================

-- Query specific partition (only scans one partition)
SELECT
    order_id,
    customer.user_id,
    order_ts
FROM goit.orders
WHERE DATE(order_ts) = CURRENT_DATE()
ORDER BY order_ts;

-- Query last 7 days (scans only 7 partitions)
SELECT
    DATE(order_ts) AS order_date,
    COUNT(*) AS orders_count,
    COUNT(DISTINCT customer.user_id) AS unique_users
FROM goit.orders
WHERE DATE(order_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY order_date
ORDER BY order_date;

-- Query date range (efficient partition pruning)
SELECT
    order_id,
    customer.user_id,
    order_ts,
    ARRAY_LENGTH(items) AS item_count
FROM goit.orders
WHERE DATE(order_ts) BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 10 DAY)
          AND DATE_SUB(CURRENT_DATE(), INTERVAL 5 DAY)
ORDER BY order_ts;

-- BAD PRACTICE: Full table scan (no partition pruning)
-- Avoid this - scans all partitions
SELECT
    order_id,
    order_ts
FROM goit.orders
WHERE EXTRACT(HOUR FROM order_ts) = 10;  -- No partition filter!

-- GOOD PRACTICE: Combine partition filter with other conditions
SELECT
    order_id,
    order_ts
FROM goit.orders
WHERE DATE(order_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND EXTRACT(HOUR FROM order_ts) = 10;


-- ============================================
-- 3. CLUSTERING BENEFITS
-- ============================================

-- Query using cluster column (efficient due to clustering by order_ts)
SELECT
    order_id,
    customer.user_id,
    order_ts
FROM goit.orders
WHERE order_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 DAY)
  AND order_ts < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)
ORDER BY order_ts;

-- Filter by clustered column with aggregation
SELECT
    DATE_TRUNC(order_ts, MONTH ) AS order_date,
    COUNT(*) AS order_count,
    SUM(ARRAY_LENGTH(items)) AS total_items
FROM goit.orders
WHERE order_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 DAY)
GROUP BY order_date
ORDER BY order_date;

-- Check clustering information
SELECT
    table_name,
    clustering_ordinal_position,
    clustering_column_name
FROM `goit.INFORMATION_SCHEMA.CLUSTERING_COLUMNS`
WHERE table_name = 'orders';


-- ============================================
-- 4. LAG - Access previous row's value
-- ============================================

-- Compare each order timestamp with the previous order timestamp
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LAG(order_ts) OVER (ORDER BY order_ts) AS previous_order_ts,
    TIMESTAMP_DIFF(
            order_ts,
            LAG(order_ts) OVER (ORDER BY order_ts),
            HOUR
    ) AS hours_since_prev_order
FROM goit.orders
ORDER BY order_ts;

-- Compare order values with previous order (per user)
SELECT
    order_id,
    customer.user_id,
    order_ts,
    ARRAY_LENGTH(items) AS item_count,
    LAG(ARRAY_LENGTH(items)) OVER (
        PARTITION BY customer.user_id
        ORDER BY order_ts
        ) AS prev_order_item_count
FROM goit.orders
ORDER BY customer.user_id, order_ts;

-- Calculate day-over-day change in orders
SELECT
    order_date,
    order_count,
    LAG(order_count) OVER (ORDER BY order_date) AS prev_day_orders,
    order_count - LAG(order_count) OVER (ORDER BY order_date) AS daily_change,
    ROUND(
            100.0 * (order_count - LAG(order_count) OVER (ORDER BY order_date))
                / LAG(order_count) OVER (ORDER BY order_date),
            2
    ) AS pct_change
FROM (
         SELECT
             DATE(order_ts) AS order_date,
             COUNT(*) AS order_count
         FROM goit.orders
         GROUP BY order_date
     )
ORDER BY order_date;

-- LAG with offset (compare with 2 orders ago)
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LAG(order_ts, 1) OVER (ORDER BY order_ts) AS prev_1_order_ts,
    LAG(order_ts, 2) OVER (ORDER BY order_ts) AS prev_2_order_ts,
    LAG(order_ts, 3) OVER (ORDER BY order_ts) AS prev_3_order_ts
FROM goit.orders
ORDER BY order_ts;

-- LAG with default value
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LAG(customer.user_id, 1, 0) OVER (ORDER BY order_ts) AS prev_user_id
FROM goit.orders
ORDER BY order_ts;

-- Compare payment amounts with previous order
SELECT
    order_id,
    customer.user_id,
    payment.method,
    payment.amount,
    LAG(payment.amount) OVER (
        PARTITION BY customer.user_id, payment.method
        ORDER BY order_ts
        ) AS prev_payment_amount
FROM goit.orders
         CROSS JOIN UNNEST(settlement.payments) AS payment
ORDER BY customer.user_id, payment.method, order_ts;


-- ============================================
-- 5. LEAD - Access next row's value
-- ============================================

-- Look ahead to next order
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LEAD(order_ts) OVER (ORDER BY order_ts) AS next_order_ts,
    TIMESTAMP_DIFF(
                    LEAD(order_ts) OVER (ORDER BY order_ts),
                    order_ts,
                    HOUR
    ) AS hours_until_next_order
FROM goit.orders
ORDER BY order_ts;

-- Compare current order with next order per user
SELECT
    order_id,
    customer.user_id,
    order_ts,
    ARRAY_LENGTH(items) AS item_count,
    LEAD(ARRAY_LENGTH(items)) OVER (
        PARTITION BY customer.user_id
        ORDER BY order_ts
        ) AS next_order_item_count
FROM goit.orders
ORDER BY customer.user_id, order_ts;

-- LEAD with offset (look ahead 2 orders)
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LEAD(order_ts, 1) OVER (ORDER BY order_ts) AS next_1_order_ts,
    LEAD(order_ts, 2) OVER (ORDER BY order_ts) AS next_2_order_ts
FROM goit.orders
ORDER BY order_ts;

-- LEAD with default value
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LEAD(customer.user_id, 1, 9999) OVER (ORDER BY order_ts) AS next_user_id
FROM goit.orders
ORDER BY order_ts;

-- Predict future trend
SELECT
    order_date,
    order_count,
    LEAD(order_count) OVER (ORDER BY order_date) AS next_day_orders,
    LEAD(order_count) OVER (ORDER BY order_date) - order_count AS expected_change
FROM (
         SELECT
             DATE(order_ts) AS order_date,
             COUNT(*) AS order_count
         FROM goit.orders
         GROUP BY order_date
     )
ORDER BY order_date;


-- ============================================
-- 6. COMBINED LAG and LEAD
-- ============================================

-- See previous and next order timestamps
SELECT
    order_id,
    customer.user_id,
    LAG(order_ts) OVER (ORDER BY order_ts) AS prev_order_ts,
    order_ts,
    LEAD(order_ts) OVER (ORDER BY order_ts) AS next_order_ts
FROM goit.orders
ORDER BY order_ts;

-- Calculate moving average with LAG and LEAD
SELECT
    order_date,
    order_count,
    LAG(order_count, 1) OVER (ORDER BY order_date) AS prev_day,
    LEAD(order_count, 1) OVER (ORDER BY order_date) AS next_day,
    ROUND(
            (
                COALESCE(LAG(order_count, 1) OVER (ORDER BY order_date), 0) +
                order_count +
                COALESCE(LEAD(order_count, 1) OVER (ORDER BY order_date), 0)
                ) / 3.0,
            2
    ) AS three_day_moving_avg
FROM (
         SELECT
             DATE(order_ts) AS order_date,
             COUNT(*) AS order_count
         FROM goit.orders
         GROUP BY order_date
     )
ORDER BY order_date;

-- Compare item counts: previous, current, next
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LAG(ARRAY_LENGTH(items)) OVER (PARTITION BY customer.user_id ORDER BY order_ts) AS prev_items,
    ARRAY_LENGTH(items) AS current_items,
    LEAD(ARRAY_LENGTH(items)) OVER (PARTITION BY customer.user_id ORDER BY order_ts) AS next_items
FROM goit.orders
ORDER BY customer.user_id, order_ts;

-- Find local peaks (current > both previous and next)
SELECT
    order_date,
    order_count,
    CASE
        WHEN order_count > COALESCE(LAG(order_count) OVER (ORDER BY order_date), 0)
            AND order_count > COALESCE(LEAD(order_count) OVER (ORDER BY order_date), 0)
            THEN 'PEAK'
        WHEN order_count < COALESCE(LAG(order_count) OVER (ORDER BY order_date), 999)
            AND order_count < COALESCE(LEAD(order_count) OVER (ORDER BY order_date), 999)
            THEN 'VALLEY'
        ELSE 'NORMAL'
        END AS trend_type
FROM (
         SELECT
             DATE(order_ts) AS order_date,
             COUNT(*) AS order_count
         FROM goit.orders
         GROUP BY order_date
     )
ORDER BY order_date;


-- ============================================
-- 7. WINDOW FUNCTIONS with PARTITION BY
-- ============================================

-- LAG/LEAD per user with partition
SELECT
    order_id,
    customer.user_id,
    order_ts,
    LAG(order_ts) OVER (
        PARTITION BY customer.user_id
        ORDER BY order_ts
        ) AS prev_order_for_user,
    LEAD(order_ts) OVER (
        PARTITION BY customer.user_id
        ORDER BY order_ts
        ) AS next_order_for_user
FROM goit.orders
ORDER BY customer.user_id, order_ts;

-- Running total per user with LAG
SELECT
    order_id,
    customer.user_id,
    order_ts,
    ARRAY_LENGTH(items) AS items,
    SUM(ARRAY_LENGTH(items)) OVER (
        PARTITION BY customer.user_id
        ORDER BY order_ts
        ) AS running_total_items,
    LAG(SUM(ARRAY_LENGTH(items)) OVER (
        PARTITION BY customer.user_id
        ORDER BY order_ts
        )) OVER (
        PARTITION BY customer.user_id
        ORDER BY order_ts
        ) AS prev_running_total
FROM goit.orders
ORDER BY customer.user_id, order_ts;

-- Rank orders and compare with previous/next ranked order
SELECT
    order_id,
    customer.user_id,
    order_ts,
    ARRAY_LENGTH(items) AS item_count,
    RANK() OVER (ORDER BY ARRAY_LENGTH(items) DESC) AS rank,
    LAG(order_id) OVER (ORDER BY ARRAY_LENGTH(items) DESC) AS prev_ranked_order,
    LEAD(order_id) OVER (ORDER BY ARRAY_LENGTH(items) DESC) AS next_ranked_order
FROM goit.orders
ORDER BY rank;


-- ============================================
-- 8. COMBINING PARTITIONS, CLUSTERING, LAG/LEAD
-- ============================================

-- Efficient query using partition + clustering + window functions
SELECT
    order_id,
    customer.user_id,
    order_ts,
    ARRAY_LENGTH(items) AS item_count,
    LAG(ARRAY_LENGTH(items)) OVER (ORDER BY order_ts) AS prev_item_count,
    LEAD(ARRAY_LENGTH(items)) OVER (ORDER BY order_ts) AS next_item_count
FROM goit.orders
WHERE DATE(order_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)  -- Partition pruning
  AND order_ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 168 HOUR)  -- Clustering benefit
ORDER BY order_ts;

-- Daily trend analysis with partition metadata
WITH daily_stats AS (
    SELECT
        DATE(order_ts) AS order_date,
        COUNT(*) AS order_count,
        COUNT(DISTINCT customer.user_id) AS unique_users,
        SUM(ARRAY_LENGTH(items)) AS total_items
    FROM goit.orders
    WHERE DATE(order_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY order_date
)
SELECT
    order_date,
    order_count,
    unique_users,
    total_items,
    LAG(order_count) OVER (ORDER BY order_date) AS prev_day_orders,
    LEAD(order_count) OVER (ORDER BY order_date) AS next_day_orders,
    order_count - LAG(order_count) OVER (ORDER BY order_date) AS day_over_day_change
FROM daily_stats
ORDER BY order_date;

-- User behavior analysis with window functions
SELECT
    customer.user_id,
    order_ts,
    ARRAY_LENGTH(items) AS item_count,
    ROW_NUMBER() OVER (PARTITION BY customer.user_id ORDER BY order_ts) AS order_sequence,
    LAG(order_ts) OVER (PARTITION BY customer.user_id ORDER BY order_ts) AS prev_order_ts,
    TIMESTAMP_DIFF(
            order_ts,
            LAG(order_ts) OVER (PARTITION BY customer.user_id ORDER BY order_ts),
            DAY
    ) AS days_since_last_order,
    LEAD(order_ts) OVER (PARTITION BY customer.user_id ORDER BY order_ts) AS next_order_ts
FROM goit.orders
WHERE DATE(order_ts) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY customer.user_id, order_ts;


select * from goit.event_logs
-- ============================================
-- 1. LAG - Track previous events per user
-- ============================================

-- Get previous event for each user
SELECT
  user_id,
  event_name,
  event_time,
  LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event,
  LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event_time
FROM goit.event_logs
ORDER BY user_id, event_time;

-- Calculate time between events

with event_diffs as (
SELECT
  user_id,
  event_name,
  event_time,
  LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event,
  TIMESTAMP_DIFF(
    event_time,
    LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time),
    SECOND
  ) AS seconds_since_prev_event
FROM goit.event_logs
ORDER BY user_id, event_time
)
select user_id,
sum(seconds_since_prev_event) as total_time
from event_diffs
group by user_id;

-- Track previous screen visited
SELECT
  user_id,
  event_name,
  screen,
  event_time,
  LAG(screen) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_screen,
  LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event
FROM goit.event_logs
ORDER BY user_id, event_time;

-- Find average time from view_product to add_to_cart
SELECT
  user_id,
  event_name,
  event_time,
  prev_event,
  seconds_since_prev_event,
  ROUND(seconds_since_prev_event / 60.0, 2) AS minutes_since_prev_event
FROM (
  SELECT
    user_id,
    event_name,
    event_time,
    LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event,
    TIMESTAMP_DIFF(
      event_time,
      LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time),
      SECOND
    ) AS seconds_since_prev_event
  FROM goit.event_logs
)
WHERE event_name = 'add_to_cart'
  AND prev_event = 'view_product'
ORDER BY user_id;

-- Track product changes (what product user viewed before current)
SELECT
  user_id,
  event_name,
  product_id,
  event_time,
  LAG(product_id) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_product_id,
  CASE
    WHEN product_id != LAG(product_id) OVER (PARTITION BY user_id ORDER BY event_time)
    THEN 'Product Changed'
    ELSE 'Same Product'
  END AS product_transition
FROM goit.event_logs
WHERE product_id != 'N/A'
ORDER BY user_id, event_time;

-- Find users who went back to search after viewing product
SELECT
  user_id,
  event_name,
  event_time,
  prev_event
FROM (
  SELECT
    user_id,
    event_name,
    event_time,
    LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event
  FROM goit.event_logs
)
WHERE event_name = 'search'
  AND prev_event = 'view_product'
ORDER BY user_id, event_time;


-- ============================================
-- 2. LEAD - Look ahead to next events
-- ============================================

-- Get next event for each user
SELECT
  user_id,
  event_name,
  event_time,
  LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event,
  LEAD(event_time) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event_time
FROM goit.event_logs
ORDER BY user_id, event_time;

-- Calculate time until next event
SELECT
  user_id,
  event_name,
  event_time,
  LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event,
  TIMESTAMP_DIFF(
    LEAD(event_time) OVER (PARTITION BY user_id ORDER BY event_time),
    event_time,
    SECOND
  ) AS seconds_until_next_event
FROM goit.event_logs
ORDER BY user_id, event_time;

-- Check if user purchased after adding to cart
SELECT
  user_id,
  event_name,
  product_id,
  event_time,
  LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event,
  CASE
    WHEN event_name = 'add_to_cart'
     AND LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) = 'purchase'
    THEN 'Converted'
    WHEN event_name = 'add_to_cart'
    THEN 'Abandoned Cart'
    ELSE NULL
  END AS cart_outcome
FROM goit.event_logs
WHERE event_name = 'add_to_cart'
ORDER BY user_id, event_time;

-- Predict next screen user will visit
SELECT
  user_id,
  screen AS current_screen,
  event_time,
  LEAD(screen) OVER (PARTITION BY user_id ORDER BY event_time) AS next_screen,
  LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event
FROM goit.event_logs
ORDER BY user_id, event_time;

-- Find drop-off points (events with no next event)
SELECT
  user_id,
  event_name AS last_event,
  screen AS last_screen,
  event_time AS last_event_time
FROM (
  SELECT
    user_id,
    event_name,
    screen,
    event_time,
    LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event
  FROM goit.event_logs
)
WHERE next_event IS NULL
ORDER BY user_id;


-- ============================================
-- 3. COMBINED LAG and LEAD
-- ============================================

-- See full event context (previous, current, next)
SELECT
  user_id,
  LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event,
  event_name AS current_event,
  LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event,
  event_time
FROM goit.event_logs
ORDER BY user_id, event_time;

-- Calculate time spent on each event (time until next event)
SELECT
  user_id,
  event_name,
  screen,
  event_time,
  LEAD(event_time) OVER (PARTITION BY user_id ORDER BY event_time) AS next_event_time,
  TIMESTAMP_DIFF(
    LEAD(event_time) OVER (PARTITION BY user_id ORDER BY event_time),
    event_time,
    SECOND
  ) AS time_spent_seconds
FROM goit.event_logs
ORDER BY user_id, event_time;

-- Track event sequences (3-event patterns)
SELECT
  user_id,
  LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS event_1,
  event_name AS event_2,
  LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS event_3,
  CONCAT(
    COALESCE(LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time), 'START'),
    ' -> ',
    event_name,
    ' -> ',
    COALESCE(LEAD(event_name) OVER (PARTITION BY user_id ORDER BY event_time), 'END')
  ) AS event_sequence
FROM goit.event_logs
ORDER BY user_id, event_time;


-- ============================================
-- 4. FUNNEL ANALYSIS - Basic Conversion Funnel
-- ============================================

-- Overall funnel: open_app -> view_product -> add_to_cart -> purchase
WITH funnel_events AS (
  SELECT
    COUNT(DISTINCT CASE WHEN event_name = 'open_app' THEN user_id END) AS step_1_open_app,
    COUNT(DISTINCT CASE WHEN event_name = 'view_product' THEN user_id END) AS step_2_view_product,
    COUNT(DISTINCT CASE WHEN event_name = 'add_to_cart' THEN user_id END) AS step_3_add_to_cart,
    COUNT(DISTINCT CASE WHEN event_name = 'purchase' THEN user_id END) AS step_4_purchase
  FROM goit.event_logs
)
SELECT
  'open_app' AS funnel_step,
  1 AS step_number,
  step_1_open_app AS users,
  100.0 AS pct_of_previous,
  ROUND(100.0 * step_1_open_app / step_1_open_app, 2) AS pct_of_total
FROM funnel_events
UNION ALL
SELECT
  'view_product',
  2,
  step_2_view_product,
  ROUND(100.0 * step_2_view_product / step_1_open_app, 2),
  ROUND(100.0 * step_2_view_product / step_1_open_app, 2)
FROM funnel_events
UNION ALL
SELECT
  'add_to_cart',
  3,
  step_3_add_to_cart,
  ROUND(100.0 * step_3_add_to_cart / step_2_view_product, 2),
  ROUND(100.0 * step_3_add_to_cart / step_1_open_app, 2)
FROM funnel_events
UNION ALL
SELECT
  'purchase',
  4,
  step_4_purchase,
  ROUND(100.0 * step_4_purchase / step_3_add_to_cart, 2),
  ROUND(100.0 * step_4_purchase / step_1_open_app, 2)
FROM funnel_events
ORDER BY step_number;


-- ============================================
-- 5. FUNNEL ANALYSIS - Per User Journey
-- ============================================

-- Track which funnel steps each user completed
WITH user_funnel AS (
  SELECT
    user_id,
    MAX(CASE WHEN event_name = 'open_app' THEN 1 ELSE 0 END) AS has_open_app,
    MAX(CASE WHEN event_name = 'view_product' THEN 1 ELSE 0 END) AS has_view_product,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS has_add_to_cart,
    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
  FROM goit.event_logs
  GROUP BY user_id
)
SELECT
  user_id,
  CASE
    WHEN has_purchase = 1 THEN 'Completed Purchase'
    WHEN has_add_to_cart = 1 THEN 'Added to Cart (No Purchase)'
    WHEN has_view_product = 1 THEN 'Viewed Product (No Cart)'
    WHEN has_open_app = 1 THEN 'Opened App Only'
    ELSE 'No Activity'
  END AS funnel_stage,
  has_open_app,
  has_view_product,
  has_add_to_cart,
  has_purchase
FROM user_funnel
ORDER BY user_id;

-- Count users at each funnel exit point
WITH user_funnel AS (
  SELECT
    user_id,
    MAX(CASE WHEN event_name = 'open_app' THEN 1 ELSE 0 END) AS has_open_app,
    MAX(CASE WHEN event_name = 'view_product' THEN 1 ELSE 0 END) AS has_view_product,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS has_add_to_cart,
    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
  FROM goit.event_logs
  GROUP BY user_id
)
SELECT
  CASE
    WHEN has_purchase = 1 THEN 'Completed Purchase'
    WHEN has_add_to_cart = 1 THEN 'Added to Cart (No Purchase)'
    WHEN has_view_product = 1 THEN 'Viewed Product (No Cart)'
    WHEN has_open_app = 1 THEN 'Opened App Only'
  END AS funnel_stage,
  COUNT(*) AS user_count
FROM user_funnel
GROUP BY funnel_stage
ORDER BY
  CASE funnel_stage
    WHEN 'Completed Purchase' THEN 1
    WHEN 'Added to Cart (No Purchase)' THEN 2
    WHEN 'Viewed Product (No Cart)' THEN 3
    WHEN 'Opened App Only' THEN 4
  END;


-- ============================================
-- 6. FUNNEL ANALYSIS - By Platform
-- ============================================

-- Compare funnel conversion by platform (iOS vs Android)
WITH platform_funnel AS (
  SELECT
    platform,
    COUNT(DISTINCT CASE WHEN event_name = 'open_app' THEN user_id END) AS step_1_open_app,
    COUNT(DISTINCT CASE WHEN event_name = 'view_product' THEN user_id END) AS step_2_view_product,
    COUNT(DISTINCT CASE WHEN event_name = 'add_to_cart' THEN user_id END) AS step_3_add_to_cart,
    COUNT(DISTINCT CASE WHEN event_name = 'purchase' THEN user_id END) AS step_4_purchase
  FROM goit.event_logs
  GROUP BY platform
)
SELECT
  platform,
  step_1_open_app AS opened_app,
  step_2_view_product AS viewed_product,
  step_3_add_to_cart AS added_to_cart,
  step_4_purchase AS purchased,
  ROUND(100.0 * step_2_view_product / step_1_open_app, 2) AS pct_open_to_view,
  ROUND(100.0 * step_3_add_to_cart / step_2_view_product, 2) AS pct_view_to_cart,
  ROUND(100.0 * step_4_purchase / step_3_add_to_cart, 2) AS pct_cart_to_purchase,
  ROUND(100.0 * step_4_purchase / step_1_open_app, 2) AS overall_conversion
FROM platform_funnel
ORDER BY platform;


-- ============================================
-- 7. FUNNEL ANALYSIS - Time-based Funnel
-- ============================================

-- Analyze time between funnel steps
WITH user_events AS (
  SELECT
    user_id,
    event_name,
    event_time,
    LAG(event_name) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event,
    TIMESTAMP_DIFF(
      event_time,
      LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time),
      SECOND
    ) AS seconds_since_prev
  FROM goit.event_logs
)
SELECT
  CONCAT(prev_event, ' -> ', event_name) AS funnel_transition,
  COUNT(*) AS transition_count,
  ROUND(AVG(seconds_since_prev), 2) AS avg_seconds,
  MIN(seconds_since_prev) AS min_seconds,
  MAX(seconds_since_prev) AS max_seconds
FROM user_events
WHERE prev_event IS NOT NULL
GROUP BY funnel_transition
ORDER BY transition_count DESC;

-- Find users who completed purchase within specific time
WITH user_journey AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'open_app' THEN event_time END) AS first_open,
    MAX(CASE WHEN event_name = 'purchase' THEN event_time END) AS purchase_time
  FROM goit.event_logs
  GROUP BY user_id
)
SELECT
  user_id,
  first_open,
  purchase_time,
  TIMESTAMP_DIFF(purchase_time, first_open, MINUTE) AS minutes_to_purchase,
  CASE
    WHEN purchase_time IS NULL THEN 'Did Not Purchase'
    WHEN TIMESTAMP_DIFF(purchase_time, first_open, MINUTE) <= 5 THEN 'Fast Buyer (<5 min)'
    WHEN TIMESTAMP_DIFF(purchase_time, first_open, MINUTE) <= 60 THEN 'Normal Buyer (5-60 min)'
    ELSE 'Slow Buyer (>60 min)'
  END AS buyer_speed
FROM user_journey
ORDER BY user_id;


-- ============================================
-- 8. FUNNEL ANALYSIS - Sequential Funnel (strict order)
-- ============================================

-- Check if users followed exact funnel sequence
WITH user_sequence AS (
  SELECT
    user_id,
    STRING_AGG(event_name, ' -> ' ORDER BY event_time) AS event_sequence
  FROM goit.event_logs
  GROUP BY user_id
)
SELECT
  user_id,
  event_sequence,
  CASE
    WHEN event_sequence LIKE '%open_app -> % -> view_product -> add_to_cart -> purchase%' THEN 'Perfect Funnel'
    WHEN event_sequence LIKE '%open_app -> % -> view_product -> add_to_cart%' THEN 'Cart Abandonment'
    WHEN event_sequence LIKE '%open_app -> % -> view_product%' THEN 'Browsing Only'
    ELSE 'Other Path'
  END AS funnel_pattern
FROM user_sequence
ORDER BY user_id;


-- ============================================
-- 9. ADVANCED FUNNEL - Drop-off Analysis
-- ============================================

-- Identify where users drop off in the funnel
WITH funnel_steps AS (
  SELECT
    user_id,
    event_name,
    event_time,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_time DESC) AS is_last_event
  FROM goit.event_logs
)
SELECT
  event_name AS last_event_before_dropoff,
  COUNT(*) AS users_dropped_off,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_dropoffs
FROM funnel_steps
WHERE is_last_event = 1
  AND event_name != 'purchase'  -- Exclude completed purchases
GROUP BY event_name
ORDER BY users_dropped_off DESC;


-- ============================================
-- 10. SESSION ANALYSIS with LAG/LEAD
-- ============================================

-- Define sessions (gap > 30 minutes = new session)
WITH session_breaks AS (
  SELECT
    user_id,
    event_name,
    event_time,
    LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) AS prev_event_time,
    TIMESTAMP_DIFF(
      event_time,
      LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time),
      MINUTE
    ) AS minutes_since_prev,
    CASE
      WHEN LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) IS NULL THEN 1
      WHEN TIMESTAMP_DIFF(
        event_time,
        LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time),
        MINUTE
      ) > 30 THEN 1
      ELSE 0
    END AS is_new_session
  FROM goit.event_logs
),
sessions AS (
  SELECT
    user_id,
    event_name,
    event_time,
    SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY event_time) AS session_id
  FROM session_breaks
)
SELECT
  user_id,
  session_id,
  COUNT(*) AS events_in_session,
  MIN(event_time) AS session_start,
  MAX(event_time) AS session_end,
  TIMESTAMP_DIFF(MAX(event_time), MIN(event_time), MINUTE) AS session_duration_minutes,
  STRING_AGG(event_name, ' -> ' ORDER BY event_time) AS session_path
FROM sessions
GROUP BY user_id, session_id
ORDER BY user_id, session_id;
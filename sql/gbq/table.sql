CREATE OR REPLACE TABLE goit.orders
PARTITION BY DATE_TRUNC(order_ts, MONTH)
CLUSTER BY order_ts
AS
WITH days AS (
  SELECT i
  FROM UNNEST(GENERATE_ARRAY(0, 40000)) AS i
)
SELECT
  GENERATE_UUID() AS order_id,
  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 - i DAY) AS order_ts,
  STRUCT(
    1000 + i AS user_id,
    'UA' AS country,
    STRUCT('Kyiv' AS city, 'Europe/Kyiv' AS tz) AS location
  ) AS customer,
  ARRAY(
    SELECT AS STRUCT
      CONCAT('SKU-', CAST(off AS STRING)) AS sku,
      off AS qty,
      ROUND(9.99 + off * 3.15, 2) AS price,
      ['tag-a', 'tag-b'] AS tags
    FROM UNNEST([1, 2 + MOD(i, 2)]) AS off
  ) AS items,
  [
    STRUCT('placed' AS status,  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 - i DAY) AS ts),
    STRUCT('paid' AS status,    TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 29 - i DAY) AS ts),
    STRUCT('shipped' AS status, TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 28 - i DAY) AS ts)
  ] AS status_history,
  STRUCT(
    'USD' AS currency,
    [STRUCT('card' AS method, CAST(25.00 AS NUMERIC) AS amount),
     STRUCT('coupon' AS method, CAST(5.00 AS NUMERIC) AS amount)] AS payments
  ) AS settlement
FROM days;
-- Track MV refresh times: table + trigger to auto-update timestamp
CREATE TABLE IF NOT EXISTS example.public.mv_refresh_log (
    mv_name        text PRIMARY KEY,
    last_refreshed timestamptz NOT NULL DEFAULT now()
);

-- Ensure a row exists for our MV
INSERT INTO example.public.mv_refresh_log (mv_name)
VALUES ('example.public.mv_department_salary')
ON CONFLICT (mv_name) DO NOTHING;

-- Helper function to update the log after refresh
CREATE OR REPLACE FUNCTION example.public.mark_mv_refreshed(p_mv_name text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE example.public.mv_refresh_log
     SET last_refreshed = now()
   WHERE mv_name = p_mv_name;
  IF NOT FOUND THEN
    INSERT INTO example.public.mv_refresh_log (mv_name, last_refreshed)
    VALUES (p_mv_name, now());
  END IF;
END$$;

-- Usage after you refresh the MV:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY example.public.mv_department_salary;
-- SELECT example.public.mark_mv_refreshed('example.public.mv_department_salary');

-- Query last MV refresh time
SELECT mv_name, last_refreshed
FROM example.public.mv_refresh_log
WHERE mv_name = 'example.public.mv_department_salary';

-- Indexes on the MV to speed up queries (optional but recommended)
CREATE UNIQUE INDEX IF NOT EXISTS mv_department_salary_pk
  ON example.public.mv_department_salary (department_id);

CREATE INDEX IF NOT EXISTS mv_department_salary_employee_count
  ON example.public.mv_department_salary (employee_count DESC);

-- Show index metadata (names, definitions, creation times if tracked)
-- PostgreSQL doesn't store index creation time by default; use pg_stat_user_indexes for activity stats.
SELECT
    n.nspname              AS schema_name,
    c.relname              AS index_name,
    pg_get_indexdef(c.oid) AS index_def,
    i.indisunique          AS is_unique,
    i.indisvalid           AS is_valid,
    i.indisready           AS is_ready,
    s.idx_scan             AS idx_scan_count,
    s.idx_tup_read         AS tuples_read,
    s.idx_tup_fetch        AS tuples_fetched
FROM pg_index i
JOIN pg_class c        ON c.oid = i.indexrelid
JOIN pg_class t        ON t.oid = i.indrelid
JOIN pg_namespace n    ON n.oid = t.relnamespace
LEFT JOIN pg_stat_user_indexes s ON s.indexrelid = c.oid
WHERE n.nspname = 'example'
  AND t.relname IN ('employees', 'mv_department_salary');

-- For index bloat/size and last vacuum/analyze times (approximate health/recency)
SELECT
  n.nspname  AS schema_name,
  c.relname  AS relation_name,
  pg_relation_size(c.oid)      AS rel_size_bytes,
  pg_total_relation_size(c.oid) AS total_size_bytes,
  s.last_vacuum,
  s.last_autovacuum,
  s.last_analyze,
  s.last_autoanalyze
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_all_tables s ON s.relid = c.oid
WHERE n.nspname = 'example'
  AND c.relname IN ('employees', 'mv_department_salary');

-- Optional: function to humanize sizes
CREATE OR REPLACE FUNCTION example.public.size_pretty(bytes bigint)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT pg_size_pretty(bytes)
$$;

-- Example report with human-readable sizes for MV and its indexes
WITH rels AS (
  SELECT c.oid, n.nspname AS schema_name, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'example'
    AND c.relname IN ('mv_department_salary')
), idx AS (
  SELECT i.indexrelid AS oid, n.nspname AS schema_name, c.relname
  FROM pg_index i
  JOIN pg_class c ON c.oid = i.indexrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE i.indrelid IN (SELECT oid FROM rels)
)
SELECT
  x.schema_name,
  x.relname,
  example.public.size_pretty(pg_relation_size(x.oid))       AS rel_size,
  example.public.size_pretty(pg_total_relation_size(x.oid)) AS total_with_indexes
FROM (
  SELECT * FROM rels
  UNION ALL
  SELECT * FROM idx
) x
ORDER BY x.relname;
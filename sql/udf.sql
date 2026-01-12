-- Create a function to URL decode text (including Cyrillic)
CREATE OR REPLACE FUNCTION url_decode(text) RETURNS text AS $$
DECLARE
  result text := '';
  i int := 1;
  len int := length($1);
  c char(1);
  hex text;
BEGIN
  WHILE i <= len LOOP
    c := substr($1, i, 1);
    IF c = '%' AND i+2 <= len THEN
      hex := substr($1, i+1, 2);
      result := result || convert_from(decode(hex, 'hex'), 'UTF8');
      i := i + 3;
    ELSE
      result := result || c;
      i := i + 1;
    END IF;
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- Use the function to decode the Cyrillic text
SELECT url_decode('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4');



SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS function_arguments,
    CASE
        WHEN l.lanname = 'internal' THEN 'SQL'
        ELSE l.lanname
    END AS language,
    CASE
        WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
        WHEN p.provolatile = 's' THEN 'STABLE'
        WHEN p.provolatile = 'v' THEN 'VOLATILE'
    END AS volatility,
    CASE WHEN p.proisstrict THEN 'STRICT' ELSE 'NOT STRICT' END AS strictness
FROM
    pg_proc p
    LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
    LEFT JOIN pg_language l ON p.prolang = l.oid
WHERE
    n.nspname NOT IN ('pg_catalog', 'information_schema')
    AND p.prokind = 'f'
ORDER BY
    schema_name, function_name;


SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM
    pg_proc p
    LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE
    p.proname = 'url_decode'
ORDER BY
    schema_name, function_name;

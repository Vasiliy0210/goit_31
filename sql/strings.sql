
-- Get length of a string (varies by SQL dialect)
SELECT LENGTH('Hello World'); -- Most databases
-- Remove spaces from both ends
SELECT TRIM('   Hello World   ');

-- Remove spaces from left side only
SELECT LTRIM('   Hello World   ');

-- Remove spaces from right side only
SELECT RTRIM('   Hello World   ');

-- Remove specific characters
SELECT TRIM('X' FROM 'XXXHello WorldXXX'); -- In many SQL dialects

-- Extract substring (position, length)
SELECT SUBSTRING('Hello World', 1, 5); -- Returns 'Hello'

-- Oracle syntax
SELECT SUBSTR('Hello World', 1, 5) ;

-- Starting from end (negative position in some dialects)
SELECT SUBSTRING('Hello World', -5, 5); -- Returns 'World' in some dialects


-- PostgreSQL
SELECT SPLIT_PART('apple,banana,orange', ',', 1); -- Returns 'apple'
SELECT SPLIT_PART('apple, banana,orange', ',', 2); -- Returns 'banana'



-- Using string functions and recursive CTE (works in many dialects)
-- Extract substring matching a pattern
SELECT REGEXP_SUBSTR('Contact: john@example.com', '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
-- Returns 'john@example.com'


-- Replace text matching a pattern
SELECT REGEXP_REPLACE('Hello 123 World 456', '[0-9]+', 'NUM');
-- Returns 'Hello NUM World NUM'

-- Using CONCAT function
SELECT CONCAT('Hello', ' ', 'World');

-- Using || operator (Oracle, PostgreSQL, SQLite)
SELECT 'Hello' || ' ' || 'World';

-- Using + operator (SQL Server)
SELECT 'Hello' + ' ' + 'World';



-- Get the length of your UTM string
SELECT LENGTH('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4');


-- Extract a substring (starting position, length)
SELECT SUBSTRING('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', 1, 20); -- Returns 'utm_source=facebook&'

-- Extract all after a specific position
SELECT SUBSTRING('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4' FROM 21);


-- Split UTM parameters by '&' and extract specific parts
SELECT
    SPLIT_PART('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', '&', 1) AS source_param,
    SPLIT_PART('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', '&', 2) AS medium_param,
    SPLIT_PART('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', '&', 3) AS campaign_param;

-- Convert string to array based on delimiter
SELECT STRING_TO_ARRAY('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', '&');

-- Access array elements
SELECT
    (STRING_TO_ARRAY('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', '&'))[1] AS first_param,
    (STRING_TO_ARRAY('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', '&'))[2] AS second_param,
    (STRING_TO_ARRAY('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', '&'))[3] AS third_param;


-- Extract UTM source value using regex
SELECT (REGEXP_MATCHES('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', 'utm_source=([^&]*)'))[1] AS utm_source;

-- Extract UTM medium value
SELECT (REGEXP_MATCHES('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', 'utm_medium=([^&]*)'))[1] AS utm_medium;

-- Extract UTM campaign value
SELECT (REGEXP_MATCHES('utm_source=facebook&utm_medium=ppc&utm_campaign=%D1%82%D1%80%D0%B5%D0%BD%D0%B4', 'utm_campaign=([^&]*)'))[1] AS utm_campaign;






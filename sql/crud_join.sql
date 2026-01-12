INSERT INTO example.public.departments (name)
VALUES
    ('Engineering'),
    ('Sales'),
    ('Marketing'),
    ('Human Resources'),
    ('Finance'),
    ('Operations')
ON CONFLICT (name) DO NOTHING;

UPDATE example.public.employees
    set department_id = (select department_id from departments order by random() limit 1)
WHERE department_id IS NULL;

INSERT INTO example.public.supervisors (employee_id, manager_id)
SELECT
    e.employee_id,
    (
        SELECT m.employee_id
        FROM example.public.employees m
        WHERE m.employee_id != e.employee_id  -- Can't be own manager
          AND (m.salary > e.salary OR (m.salary = e.salary AND m.hire_date < e.hire_date))
        ORDER BY random()
        LIMIT 1
    ) AS manager_id
FROM example.public.employees e
WHERE NOT EXISTS (
    SELECT 1 FROM example.public.supervisors s WHERE s.employee_id = e.employee_id
)
ON CONFLICT (employee_id) DO NOTHING;


WITH ranked AS (
    SELECT
        employee_id,
        ROW_NUMBER() OVER (ORDER BY salary DESC, hire_date ASC) AS rn,
        COUNT(*) OVER () AS total
    FROM example.public.employees
)
INSERT INTO example.public.supervisors (employee_id, manager_id)
SELECT employee_id, NULL
FROM ranked
WHERE rn <= GREATEST(1, (total * 0.1)::int)  -- Top 10% are managers
ON CONFLICT (employee_id) DO NOTHING;


-- ========================================
-- CRUD OPERATIONS EXAMPLES
-- ========================================

-- ============ CREATE (INSERT) ============

-- 1. Insert single department
INSERT INTO example.public.departments (name)
VALUES ('Engineering');

-- 2. Insert multiple departments
INSERT INTO example.public.departments (name)
VALUES
    ('Sales'),
    ('Marketing'),
    ('Human Resources'),
    ('Finance')
RETURNING department_id, name;
-- 3. Insert employee with department reference
INSERT INTO example.public.employees (employee_id, first_name, last_name, phone_number, hire_date, salary, department_id)
VALUES (1009, 'John', 'Smith', '+1234567890', '2024-01-15', 75000.00, 1);

-- 4. Insert multiple employees
INSERT INTO example.public.employees (employee_id, first_name, last_name, email, hire_date, salary, department_id)
VALUES
    (1004, 'Jane', 'Doe', 'jane.doe@example.com', '2024-02-01', 82000.00, 1),
    (1005, 'Bob', 'Johnson', 'bob.j@example.com', '2024-03-10', 68000.00, 1),
    (1006, 'Alice', 'Williams', 'alice.w@example.com', '2024-01-20', 95000.00, 1);

-- 5. Insert with SELECT (copy from existing data)
INSERT INTO example.public.employees (employee_id, first_name, last_name, email, hire_date, salary)
SELECT
    employee_id + 1000,
    first_name,
    last_name,
    'copy_' || email,
    CURRENT_DATE,
    salary * 1.1
FROM example.public.employees
WHERE salary > 70000
limit 5;

-- 6. Insert supervisor relationships
INSERT INTO example.public.supervisors (employee_id, manager_id)
VALUES
    (1001, NULL),        -- Top manager (no supervisor)
    (1002, 1001),        -- Reports to 1001
    (1003, 1001),        -- Reports to 1001
    (1004, 1002);        -- Reports to 1002

-- 7. Insert with conflict handling (UPSERT)
INSERT INTO example.public.employees (employee_id, first_name, last_name, email, hire_date, salary)
VALUES (1001, 'John', 'Smith', 'john.new@example.com', '2024-01-15', 80000.00)
ON CONFLICT (employee_id)
DO UPDATE SET
    email = EXCLUDED.email,
    salary = EXCLUDED.salary,
    last_name = EXCLUDED.last_name;

-- ============ READ (SELECT) ============

-- 1. Simple SELECT
SELECT * FROM example.public.employees;

-- 2. SELECT with WHERE
SELECT employee_id, first_name, last_name, salary
FROM example.public.employees
WHERE salary > 70000
  AND hire_date >= '2024-01-01';

-- 3. SELECT with ORDER BY and LIMIT
SELECT first_name, last_name, salary
FROM example.public.employees
ORDER BY salary DESC, last_name ASC
LIMIT 10;

-- 4. SELECT with aggregate functions
SELECT
    COUNT(*) AS total_employees,
    AVG(salary) AS avg_salary,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary,
    SUM(salary) AS total_payroll
FROM example.public.employees;

-- 5. SELECT with GROUP BY and HAVING
SELECT
    department_id,
    COUNT(*) AS employee_count,
    AVG(salary)::numeric(10,2) AS avg_salary
FROM example.public.employees
WHERE department_id IS NOT NULL
GROUP BY department_id
HAVING COUNT(*) >= 2
ORDER BY avg_salary DESC;

-- ============ UPDATE ============

-- 1. Simple UPDATE
UPDATE example.public.employees
SET salary = 85000.00
WHERE employee_id = 1001;

-- 2. UPDATE multiple columns
UPDATE example.public.employees
SET
    salary = salary * 1.05,
    email = LOWER(email)
WHERE department_id = 1
  AND hire_date < '2024-02-01';

-- 3. UPDATE with calculation
UPDATE example.public.employees
SET salary = CASE
    WHEN salary < 60000 THEN salary * 1.10
    WHEN salary < 80000 THEN salary * 1.07
    ELSE salary * 1.05
END
WHERE hire_date < '2024-01-01';

-- 4. UPDATE from another table (using subquery)
UPDATE example.public.employees e
SET salary = salary * 1.15
WHERE department_id = (
    SELECT department_id
    FROM example.public.departments
    WHERE name = ' IT'
);

-- 5. UPDATE with RETURNING
UPDATE example.public.employees
SET salary = salary + 5000
WHERE employee_id IN (1001, 1002)
RETURNING employee_id, first_name, last_name, salary;

-- ============ DELETE ============

-- 1. Simple DELETE
DELETE FROM example.public.employees
WHERE employee_id = 2002
RETURNING employee_id, first_name, last_name;

-- 2. DELETE with WHERE condition
DELETE FROM example.public.employees
WHERE hire_date < '2020-01-01'
  AND salary < 50000;

-- 3. DELETE with subquery
DELETE FROM example.public.employees
WHERE department_id IN (
    SELECT department_id
    FROM example.public.departments
    WHERE name = 'Temporary Projects'
);

-- 4. DELETE with RETURNING
DELETE FROM example.public.employees
WHERE salary > 200000
RETURNING employee_id, first_name, last_name, salary;

-- 5. DELETE all rows (use with caution!)
-- DELETE FROM example.public.employees;

-- 6. TRUNCATE (faster than DELETE for removing all rows)
-- TRUNCATE TABLE example.public.employees CASCADE;

-- ========================================
-- JOIN OPERATIONS EXAMPLES
-- ========================================

-- ============ INNER JOIN ============

-- 1. Basic INNER JOIN - employees with departments
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.salary,
    d.name AS department_name
FROM example.public.employees e
INNER JOIN example.public.departments d ON e.department_id = d.department_id
where employee_id = 2001
ORDER BY e.last_name;

-- 2. Multiple INNER JOINs - employees with departments and supervisors
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.name AS department_name,
    m.first_name || ' ' || m.last_name AS manager_name
FROM example.public.employees e
INNER JOIN example.public.departments d ON e.department_id = d.department_id
INNER JOIN example.public.supervisors s ON e.employee_id = s.employee_id
INNER JOIN example.public.employees m ON s.manager_id = m.employee_id
ORDER BY d.name, e.last_name;

-- ============ LEFT JOIN (LEFT OUTER JOIN) ============

-- 3. LEFT JOIN - all employees, with department if exists
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.salary,
    d.name as department_name
    --COALESCE(d.name, 'No Department') AS department_name
FROM example.public.employees e
LEFT JOIN example.public.departments d ON e.department_id = d.department_id
ORDER BY e.employee_id;

-- 4. LEFT JOIN - all employees with their managers (including those without managers)
SELECT
    m.salary,
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.salary,
    COALESCE(m.first_name || ' ' || m.last_name, 'No Manager') AS manager_name
    --m.salary AS manager_salary
FROM example.public.employees e
LEFT JOIN example.public.supervisors s ON e.employee_id = s.employee_id
LEFT JOIN example.public.employees m ON s.manager_id = m.employee_id
ORDER BY e.employee_id;

-- ============ RIGHT JOIN (RIGHT OUTER JOIN) ============

-- 5. RIGHT JOIN - all departments with their employees
SELECT
    d.department_id,
    d.name AS department_name,
    COUNT(e.employee_id) AS employee_count,
    COALESCE(AVG(e.salary)::numeric(10,2), 0) AS avg_salary
FROM example.public.employees e
RIGHT JOIN example.public.departments d ON e.department_id = d.department_id
GROUP BY d.department_id, d.name
ORDER BY d.name;

-- ============ FULL OUTER JOIN ============

-- 6. FULL OUTER JOIN - all employees and all departments
SELECT
    COALESCE(e.employee_id::text, 'N/A') AS employee_id,
    COALESCE(e.first_name || ' ' || e.last_name, 'No Employee') AS employee_name,
    COALESCE(d.name, 'No Department') AS department_name
FROM example.public.employees e
FULL OUTER JOIN example.public.departments d ON e.department_id = d.department_id
ORDER BY d.name NULLS LAST, e.last_name NULLS LAST;

-- ============ CROSS JOIN ============

-- 7. CROSS JOIN - Cartesian product (use carefully!)
SELECT
    e.first_name || ' ' || e.last_name AS employee,
    d.name AS department
FROM example.public.employees e
CROSS JOIN example.public.departments d
WHERE e.employee_id <= 1003  -- Limit for demonstration
ORDER BY e.employee_id, d.name;

-- ============ SELF JOIN ============

-- 8. SELF JOIN - employees and their managers (alternative to supervisor table)
SELECT
    e.employee_id AS emp_id,
    e.first_name || ' ' || e.last_name AS employee,
    e.salary AS emp_salary,
    m.employee_id AS mgr_id,
    m.first_name || ' ' || m.last_name AS manager,
    m.salary AS mgr_salary
FROM example.public.employees e
JOIN example.public.supervisors s ON e.employee_id = s.employee_id
JOIN example.public.employees m ON s.manager_id = m.employee_id
ORDER BY m.employee_id, e.employee_id;

-- ============ COMPLEX JOINS ============

-- 9. Complex query - department summary with employee details
SELECT
    d.name AS department,
    COUNT(DISTINCT e.employee_id) AS employee_count,
    AVG(e.salary)::numeric(10,2) AS avg_salary,
    MIN(e.hire_date) AS earliest_hire,
    MAX(e.hire_date) AS latest_hire,
    STRING_AGG(e.first_name || ' ' || e.last_name, ', ' ORDER BY e.salary DESC) AS employees
FROM example.public.departments d
LEFT JOIN example.public.employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.name
ORDER BY employee_count DESC, d.name;

-- 10. Hierarchical query - org chart with levels
WITH RECURSIVE org_chart AS (
    -- Anchor: top-level employees (no manager)
    SELECT
        e.employee_id,
        e.first_name || ' ' || e.last_name AS employee_name,
        e.salary,
        d.name AS department,
        NULL::text AS manager_name,
        0 AS level,
        e.employee_id::text AS path
    FROM example.public.employees e
    LEFT JOIN example.public.departments d ON e.department_id = d.department_id
    LEFT JOIN example.public.supervisors s ON e.employee_id = s.employee_id
    WHERE s.manager_id IS NULL

    UNION ALL

    -- Recursive: subordinates
    SELECT
        e.employee_id,
        e.first_name || ' ' || e.last_name,
        e.salary,
        d.name,
        oc.employee_name AS manager_name,
        oc.level + 1,
        oc.path || '>' || e.employee_id::text
    FROM example.public.employees e
    JOIN example.public.supervisors s ON e.employee_id = s.employee_id
    JOIN org_chart oc ON s.manager_id = oc.employee_id
    LEFT JOIN example.public.departments d ON e.department_id = d.department_id
)
SELECT
    REPEAT('  ', level) || employee_name AS org_structure,
    level,
    department,
    manager_name,
    salary,
    path
FROM org_chart
ORDER BY path;

-- 11. JOIN with aggregation and window functions
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee,
    d.name AS department,
    e.salary,
    AVG(e.salary) OVER (PARTITION BY d.department_id) AS dept_avg_salary,
    e.salary - AVG(e.salary) OVER (PARTITION BY d.department_id) AS salary_vs_dept_avg,
    RANK() OVER (PARTITION BY d.department_id ORDER BY e.salary DESC) AS rank_in_dept,
    COUNT(*) OVER (PARTITION BY d.department_id) AS dept_size
FROM example.public.employees e
LEFT JOIN example.public.departments d ON e.department_id = d.department_id
WHERE e.salary IS NOT NULL
ORDER BY d.name, rank_in_dept;

-- 12. Multiple conditions JOIN
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee,
    e.salary,
    m.first_name || ' ' || m.last_name AS manager,
    m.salary AS manager_salary,
    CASE
        WHEN e.salary >= m.salary THEN 'Earns more than manager'
        ELSE 'Earns less than manager'
    END AS salary_comparison
FROM example.public.employees e
JOIN example.public.supervisors s ON e.employee_id = s.employee_id
JOIN example.public.employees m ON s.manager_id = m.employee_id
WHERE e.salary IS NOT NULL
  AND m.salary IS NOT NULL
ORDER BY e.salary DESC;

-- ========================================
-- TRANSACTIONAL CRUD EXAMPLE
-- ========================================

-- Transaction example: hire a new employee with all relationships
BEGIN;

-- Insert department if doesn't exist
INSERT INTO example.public.departments (name)
VALUES ('Data Science')
ON CONFLICT (name) DO NOTHING;

-- Insert new employee
INSERT INTO example.public.employees (employee_id, first_name, last_name, email, hire_date, salary, department_id)
VALUES (
    2001,
    'Sarah',
    'Connor',
    'sarah.connor@example.com',
    CURRENT_DATE,
    90000.00,
    (SELECT department_id FROM example.public.departments WHERE name = 'Data Science')
);

-- Assign supervisor
INSERT INTO example.public.supervisors (employee_id, manager_id)
VALUES (2001, 1001);

-- Verify the insert
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS new_employee,
    d.name AS department,
    m.first_name || ' ' || m.last_name AS manager
FROM example.public.employees e
LEFT JOIN example.public.departments d ON e.department_id = d.department_id
LEFT JOIN example.public.supervisors s ON e.employee_id = s.employee_id
LEFT JOIN example.public.employees m ON s.manager_id = m.employee_id
WHERE e.employee_id = 2001;


COMMIT;
-- Or ROLLBACK; to undo all changes


SELECT
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'employees'
ORDER BY ordinal_position;


EXPLAIN (ANALYZE, BUFFERS, VERBOSE, TIMING, COSTS)
SELECT sum(budget) FROM credits
left join movies on movies.id = credits.movie_id
WHERE release_date  > '2000-01-01'

- departments_lastname (назви колонок: department_id, department_name);
- jobs_lastname (назви колонок: job_id, job_title);
- employees_ lastname (назви колонок: employee_id, first_name, last_name, department_id, job_id).


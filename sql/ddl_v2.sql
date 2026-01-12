-- 1) DDL: constraints, keys, and indexes for employees
ALTER TABLE example.public.employees
    ADD CONSTRAINT pk_employees PRIMARY KEY (employee_id);

ALTER TABLE example.public.employees
    ADD CONSTRAINT uq_employees_email UNIQUE (email);

ALTER TABLE example.public.employees
    ALTER COLUMN first_name SET NOT NULL,
    ALTER COLUMN last_name SET NOT NULL,
    ALTER COLUMN hire_date SET NOT NULL;

ALTER TABLE example.public.employees
    ADD CONSTRAINT chk_salary_nonnegative CHECK (salary IS NULL OR salary >= 0);

CREATE INDEX IF NOT EXISTS idx_employees_last_name ON example.public.employees(last_name);
CREATE INDEX IF NOT EXISTS idx_employees_hire_date ON example.public.employees(hire_date);
CREATE INDEX IF NOT EXISTS idx_employees_salary ON example.public.employees(salary);

-- 2) Related table + foreign key (departments)
CREATE TABLE IF NOT EXISTS example.public.departments (
                                                          department_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                                          name          TEXT NOT NULL UNIQUE
);

ALTER TABLE example.public.employees
    ADD COLUMN IF NOT EXISTS department_id BIGINT;

ALTER TABLE example.public.employees
    ADD CONSTRAINT fk_employees_department
        FOREIGN KEY (department_id)
            REFERENCES example.public.departments(department_id)
            ON UPDATE CASCADE
            ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_employees_department_id
    ON example.public.employees(department_id);

-- 3) Materialized view: salary aggregates by department
CREATE VIEW example.public.v_department_salary AS
SELECT
    department_id,
    COUNT(*)               AS employee_count,
    AVG(salary)            AS avg_salary,
    MIN(salary)            AS min_salary,
    MAX(salary)            AS max_salary
FROM example.public.employees
GROUP BY department_id;

REFRESH MATERIALIZED VIEW example.public.mv_department_salary;

select * from example.public.v_department_salary;
select * from example.public.mv_department_salary;


SELECT emp.*
from (
      select *
      from employees
      where salary > 60000
      order by salary desc
      limit 6
      ) as emp
where salary > (select avg(salary) from employees)
order by salary;

--CTE examples
with dept_avg as (
    select department_id, avg(salary) as avg_salary
    from employees
    group by department_id
),
emp_above_avg as (
    select e.*
    from employees e
             join dept_avg d on e.department_id = d.department_id
    where e.salary > d.avg_salary
)
select *
from dept_avg


select *
from employees

union all

select *
from employees

-- 4) Non-recursive CTE: top earners per department
WITH ranked AS (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.department_id,
        e.salary,
        DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC NULLS LAST) AS rnk
    FROM example.public.employees e
)
SELECT *
FROM ranked
WHERE rnk <= 3
ORDER BY department_id NULLS FIRST, rnk, employee_id;

-- 5) Org chart: supervisors table + recursive CTE
CREATE TABLE IF NOT EXISTS example.public.supervisors (
                                                          employee_id   INTEGER PRIMARY KEY,
                                                          manager_id    INTEGER NULL,
                                                          CONSTRAINT fk_supervisor_employee
                                                              FOREIGN KEY (employee_id)
                                                                  REFERENCES example.public.employees(employee_id)
                                                                  ON UPDATE CASCADE
                                                                  ON DELETE CASCADE,
                                                          CONSTRAINT fk_supervisor_manager
                                                              FOREIGN KEY (manager_id)
                                                                  REFERENCES example.public.employees(employee_id)
                                                                  ON UPDATE CASCADE
                                                                  ON DELETE SET NULL,
                                                          CONSTRAINT chk_not_self_managed CHECK (manager_id IS NULL OR manager_id <> employee_id)
);

CREATE INDEX IF NOT EXISTS idx_supervisors_manager_id
    ON example.public.supervisors(manager_id);

-- Recursive CTE: expand org chart from a given manager (employee_id = 1)
WITH RECURSIVE org AS (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        s.manager_id,
        0 AS depth,
        e.employee_id::text AS path
    FROM example.public.employees e
             JOIN example.public.supervisors s ON s.employee_id = e.employee_id
    WHERE e.employee_id = 1

    UNION ALL

    SELECT
        c.employee_id,
        c.first_name,
        c.last_name,
        s.manager_id,
        o.depth + 1 AS depth,
        o.path || '>' || c.employee_id::text AS path
    FROM example.public.supervisors s
             JOIN example.public.employees c ON c.employee_id = s.employee_id
             JOIN org o ON s.manager_id = o.employee_id
    WHERE position(('>' || c.employee_id::text) IN ('>' || o.path)) = 0
)
SELECT employee_id, first_name, last_name, manager_id, depth, path
FROM org
ORDER BY depth, employee_id;

-- 6) Salary bands with cumulative counts
WITH RECURSIVE
    bands AS (
        SELECT 1 AS rn, 0::numeric AS lower, 30000::numeric AS upper, '0-30k'::text AS band_name
        UNION ALL
        SELECT 2, 30000, 60000, '30-60k'
        UNION ALL
        SELECT 3, 60000, 90000, '60-90k'
        UNION ALL
        SELECT 4, 90000, 120000, '90-120k'
        UNION ALL
        SELECT 5, 120000, 999999999, '120k+'
    ),
    band_counts AS (
        SELECT
            b.rn,
            b.band_name,
            COUNT(e.*) AS cnt
        FROM bands b
                 LEFT JOIN example.public.employees e
                           ON e.salary IS NOT NULL AND e.salary >= b.lower AND e.salary < b.upper
        GROUP BY b.rn, b.band_name
    ),
    ordered AS (
        SELECT rn, band_name, cnt
        FROM band_counts
        ORDER BY rn
    ),
    rec AS (
        SELECT rn, band_name, cnt, cnt AS cumulative_cnt
        FROM ordered
        WHERE rn = 1
        UNION ALL
        SELECT o.rn, o.band_name, o.cnt, r.cumulative_cnt + o.cnt
        FROM ordered o
                 JOIN rec r ON o.rn = r.rn + 1
    )
SELECT band_name, cnt, cumulative_cnt
FROM rec
ORDER BY rn;
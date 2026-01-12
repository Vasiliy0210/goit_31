SELECT name,
  avg(vote_average)
FROM cast_kate c
LEFT JOIN movies m on m.id = c.movie_id
WHERE 1=1
--and name = 'Sigourney Weaver'
GROUP BY name
HAVING count(c.title) >= 10
ORDER BY 2 desc

select *
from employees
where hire_date >= '2020-01-01'
  and hire_date < '2023-01-01'

select split_part(email, '', 1) as domain,
       count(*) as num_employees
from employees
where hire_date >= '2020-01-01'
and hire_date <= '2022-12-31'--between '2020-01-01' and '2022-12-31'
group by 1


select *
from employees


select *,
       coalesce(random_val, salary)
from employees

select salary,
       random_val,
    coalesce(random_val,0) as result_0,
    coalesce(random_val,salary) as result_sal
from employees

select substr(product_summary,1,50) as short_summary
from products

select *
from employees
where 1=1
--and first_name like 'D%'
and left(lower(first_name),1) = right(lower(first_name),1)
--where random_val is null

SELECT LENGTH(' "Data" ')
SELECT CHAR_LENGTH('Дані')


select extract(year from hire_date) as hire_year,
       count(*) as num_hires
from employees
group by 1
order by 1


select *,
       case
            when price < 200000 then 'budget'
            when price >= 200000 and price < 300000 and discount is not null then product_name
            when left(product_name,3) = 'McL' then 'super premium'
            when price >= 300000 then 'premium'
            else 'other'
       end as price_category
from products

select
sum(case when price >= 200000 and price <300000 then 1 else 0 end) as budget_count,
sum(case when price >= 300000 then 1 else 0 end) as premium_count,
sum(case when product_name like 'A%' then 1 else 0 end) as a_products
from products



select *,
 COALESCE(NULLIF(product_summary, 'NULL'),
      substr(product_description, 1, 50) || '...') AS excerpt
FROM products p

SELECT *
FROM employees
WHERE email ~ '@example\.com'



SELECT replace(phone_number, '.', '') as phone_clean
FROM employees
WHERE phone_number ~ '^\+1\d{10}$';

select
first_name,
  hire_date,
  CASE (2025 - CAST(strftime('%Y', hire_date) AS INT))
    WHEN 5 THEN '5 years'
    WHEN 10 THEN '10 years'
    WHEN 15 THEN '15 years'
    ELSE NULL
  END AS anniversary
FROM employees;
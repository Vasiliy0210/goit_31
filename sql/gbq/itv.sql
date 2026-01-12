select count(distinct customer.user_id)
from goit.orders
where date(order_ts) <= date_sub(current_date(), interval 7 day);
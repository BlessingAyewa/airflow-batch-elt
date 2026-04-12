-- Singular test: fails if any completed order has negative recognised revenue.
-- A completed order must always have a positive revenue value.

select
    order_id,
    recognised_revenue
from {{ ref('fct_orders') }}
where recognised_revenue < 0

-- models/marts/fct_orders.sql
-- Final orders fact table for analytics and dashboards.
-- Materialised as a table — fast for repeated queries.

with orders as (
    select * from {{ ref('stg_orders') }}
),

final as(
    select 
        order_id,
        customer_id,
        order_amount,
        order_date,
        order_status,
        created_at,

        date_trunc(order_date, month)           as order_month,

        case
            when order_status = 'complete' then order_amount
            else 0
        end                                     as recognised_revenue,

        case
            when order_status = 'cancelled' then true
            else false
        end                                     as is_cancelled

    from orders
)

select * from final
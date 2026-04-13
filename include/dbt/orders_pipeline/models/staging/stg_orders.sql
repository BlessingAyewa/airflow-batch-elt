-- models/staging/stg_orders.sql
-- Cleans and standardises raw orders data from BigQuery.
-- Materialised as a view — no storage cost, always fresh.

with source as (
    select * from {{source('raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        cast(amount as numeric)         as order_amount,
        cast(order_date as date)        as order_date,
        lower(trim(status))             as order_status,
        cast(created_at as timestamp)   as created_at
    from source
    where order_id is not null
        and customer_id is not null
)

select * from renamed
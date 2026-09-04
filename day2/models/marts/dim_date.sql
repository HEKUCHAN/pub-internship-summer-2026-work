-- models/rakuten_ec/marts/dim_date.sql
with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="to_date('2020-01-01')",
        end_date="dateadd(year, 1, current_date)") }}
)
select
    to_number(to_char(date_day, 'YYYYMMDD')) as date_key,
    date_day                                 as purchase_date,   -- 購入日
    date_trunc('month', date_day)            as purchase_month,  -- 購入月（月初日）
    year(date_day)  as year,
    month(date_day) as month,
    day(date_day)   as day
from spine

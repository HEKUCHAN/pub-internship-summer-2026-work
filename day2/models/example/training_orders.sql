with load_order as (
    select
        *
    from
        {{ source('training', 'orders') }}
),

join_customer as (
    select
        t1.*,
        t2.customer_name
    from
        load_order as t1
        left join {{ source('training', 'customers') }} as t2 on t1.customer_id = t2.customer_id
),

final as (
    select
        *
    from
        join_customer
)

select *
from final

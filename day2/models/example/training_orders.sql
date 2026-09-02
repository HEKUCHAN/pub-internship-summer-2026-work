with load_order as (
    select
        *
    from
        {{ source('training', 'orders') }}
),

join_customer as (
    select
        t1.*,
        -- 列を追加しよう
    from
        load_order as t1
        -- customerをjoinしてみよう
),

final as (
    select
        *
    from
        join_customer
)

select *
from final 

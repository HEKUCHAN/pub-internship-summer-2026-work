with load_order as (
    select
        *
    from
        {{ ref('training_orders') }} -- 作成済みのmodelを参照する場合はrefを使います
),

monthly_order as (
    select
        *,
        /*
        売上を月毎に集約しよう
        */
    from
        load_order
),

final as (
    select
        *
        -- 必要な列だけに絞り込もう: 月,売上   
    from
        monthly_order
)

select *
from final 

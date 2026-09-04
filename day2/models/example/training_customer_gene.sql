with
final as (
    select
        t1.customer_gender,
        t2.gene,
        count(*) as customer_count,
        round(count(*) / sum(count(*)) over (), 2) as customer_percentage
    from
        {{ source('training', 'customers') }} as t1
    left outer join {{ ref('gene_definition') }} as t2
    on
        t1.customer_age between t2.age_lower_limit and t2.age_upper_limit
    group by
        t1.customer_gender,
        t2.gene
    order by
        t1.customer_gender,
        t2.gene
)

select *
from final

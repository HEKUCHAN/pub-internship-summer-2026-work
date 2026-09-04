-- models/rakuten_ec/marts/dim_store.sql
select
    {{ dbt_utils.generate_surrogate_key(['s.store_id']) }} as store_key,
    s.store_id,
    s.store_name,
    e.ec_site_name
from {{ ref('stg_stores') }} s
left join {{ ref('stg_ec_sites') }} e
       on e.ec_site_id = s.ec_site_id

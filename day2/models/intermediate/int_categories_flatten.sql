-- models/rakuten_ec/intermediate/int_categories_flatten.sql
with recursive cat as (
    select * from {{ ref('stg_categories') }}
),
climb as (
    -- anchor: 起点そのもの
    select category_id as leaf_id,
           category_id, category_name, category_level, parent_category_id
    from cat
    union all
    -- 親カテゴリへ1段ずつ遡る
    select c.leaf_id,
           p.category_id, p.category_name, p.category_level, p.parent_category_id
    from climb c
    join cat p on p.category_id = c.parent_category_id
)
select
    leaf_id as category_id,
    max(case when category_level = 1 then category_name end) as category_level_1,
    max(case when category_level = 2 then category_name end) as category_level_2,
    max(case when category_level = 3 then category_name end) as category_level_3,
    max(case when category_level = 4 then category_name end) as category_level_4
from climb
group by leaf_id


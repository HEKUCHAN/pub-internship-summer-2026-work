-- dim_item（設計書 §5.4）: 名寄せ済みの int_items__name_resolved にカテゴリ階層を結合する。
-- grain: 1 item_url = 1 行。カテゴリ1 NULL 行はここでは除外しない（大福帳側で NULL 許容）。
with items as (

    select * from {{ ref('int_items__name_resolved') }}

),

categories as (

    select * from {{ ref('int_categories_flatten') }}

),

final as (

    select
        items.item_key,
        items.item_url,
        items.item_name,                       -- 名寄せ後の代表名
        categories.category_level_1,
        categories.category_level_2,
        categories.category_level_3,
        categories.category_level_4
    from items
    left join categories
        on categories.category_id = items.category_id

)

select * from final

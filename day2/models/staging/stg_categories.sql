-- 設計書 §5.0: CATEGORIES を 1:1 でリネームするだけ（加工はしない）
-- 自己参照階層の平坦化は int_categories_flatten で行う（§5.1）
with source as (
    select * from {{ source('rakuten_ec', 'categories') }}
),

renamed as (
    select
        category_id,
        category_name,
        category_level,
        parent_category_id
    from source
)

select * from renamed

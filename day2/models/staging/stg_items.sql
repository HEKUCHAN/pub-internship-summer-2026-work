-- 設計書 §5.0: ITEMS を 1:1 でリネームするだけ（加工はしない）
-- item_url 単位の名寄せ・カテゴリ1 NULL 除外は dim_item で行う（§5.4）
with source as (
    select * from {{ source('rakuten_ec', 'items') }}
),

renamed as (
    select
        item_id,
        item_name,
        item_url,
        store_id,
        category_id
    from source
)

select * from renamed

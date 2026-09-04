-- 設計書 §5.0: PURCHASE_ITEMS を 1:1 でリネームするだけ（加工はしない）
-- これが最小粒度（grain: 購入1明細）。total_price / discount_amount / is_discount は fct で算出する（§5.6）
with source as (
    select * from {{ source('rakuten_ec', 'purchase_items') }}
),

renamed as (
    select
        purchase_item_id,
        purchase_id,
        item_id,
        unit_price,
        amount,
        total_price
    from source
)

select * from renamed

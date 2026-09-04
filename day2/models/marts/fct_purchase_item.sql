-- fct_purchase_item（設計書 §5.6）: 購入1明細＝1行（stg_purchase_items と同粒度・全 1,694,437 行）。
-- NULL 除外はしない（item_id NULL の133行も残す）ため、周辺テーブルは全て LEFT JOIN。
with pi as (select * from {{ ref('stg_purchase_items') }}),
     p  as (select * from {{ ref('stg_purchases') }}),
     it as (select * from {{ ref('stg_items') }})   -- 生の item_name（割引フラグ判定用）
select
    pi.purchase_item_id,
    pi.purchase_id,
    pi.item_id,
    p.purchased_at,
    to_number(to_char(p.purchased_at::date, 'YYYYMMDD'))          as date_key,
    {{ dbt_utils.generate_surrogate_key(['p.user_id_hash']) }}    as user_key,
    {{ dbt_utils.generate_surrogate_key(['it.item_url']) }}       as item_key,
    {{ dbt_utils.generate_surrogate_key(['it.store_id']) }}       as store_key,
    p.destination_postal_code,
    pi.unit_price,
    pi.amount,
    pi.unit_price * pi.amount                                     as total_price,
    it.item_name ilike '%セール%'                                as is_discount,   -- 生の名前で判定
    case
        when it.item_url is not null
            then max(pi.unit_price) over (partition by it.item_url) - pi.unit_price
    end                                                          as discount_amount
from pi
left join p  on p.purchase_id = pi.purchase_id
left join it on it.item_id    = pi.item_id

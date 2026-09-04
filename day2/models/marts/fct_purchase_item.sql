-- fct_purchase_item（設計書 §5.6）: 購入1明細＝1行（stg_purchase_items と同粒度・全 1,694,437 行）。
-- スタースキーマの中心。各 *_key は「ディメンションを結合して」採番済みキーを引く（fact は dim から組む）。
-- 縮退ディメンション（purchased_at 等）と measure（unit_price 等）は明細から直接持つ。
with purchase_items as (

    select * from {{ ref('stg_purchase_items') }}

),

purchases as (

    select * from {{ ref('stg_purchases') }}

),

items as (

    select * from {{ ref('stg_items') }}   -- item_id → item_url / store_id / 生の item_name のブリッジ

),

dim_date as (

    select * from {{ ref('dim_date') }}

),

dim_user as (

    select * from {{ ref('dim_user') }}

),

dim_item as (

    select * from {{ ref('dim_item') }}

),

dim_store as (

    select * from {{ ref('dim_store') }}

),

final as (

    select
        purchase_items.purchase_item_id,
        purchase_items.purchase_id,
        -- 縮退ディメンション
        purchases.purchased_at,
        purchases.destination_postal_code,
        -- ディメンション参照キー（dim を結合して採番済みキーを引く）
        dim_date.date_key,
        dim_user.user_key,
        dim_item.item_key,
        dim_store.store_key,
        -- 事実（measure）
        purchase_items.unit_price,
        purchase_items.amount,
        purchase_items.unit_price * purchase_items.amount as total_price,
        items.item_name ilike '%セール%' as is_discount,   -- 生の名前で判定（設計書 §5.6）
        case
            when items.item_url is not null
                then max(purchase_items.unit_price) over (partition by items.item_url) - purchase_items.unit_price
        end as discount_amount
    from purchase_items
    left join purchases on purchases.purchase_id      = purchase_items.purchase_id
    left join items     on items.item_id              = purchase_items.item_id
    left join dim_date  on dim_date.purchase_date     = purchases.purchased_at::date
    left join dim_user  on dim_user.user_id_hash      = purchases.user_id_hash
    left join dim_item  on dim_item.item_url          = items.item_url
    left join dim_store on dim_store.store_id         = items.store_id

)

select * from final

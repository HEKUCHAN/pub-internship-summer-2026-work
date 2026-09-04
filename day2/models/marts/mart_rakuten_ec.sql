-- 大福帳: テーブル定義.xlsx の23列 ＋ 課題スライドの派生列（購入日 / 購入月 / 地方 / 割引フラグ / 割引額）。
-- grain: 1購入明細＝1行。ただし instructor 回答④により category_level_1 が NULL の行は削除する
--        （CATEGORIES を category_id → parent_category_id で遡って第1階層に到達しない＝
--         実データでは item_id 欠損 or 商品の category_id 欠損の行、約22.6万行）。
-- item_name のみ名寄せ後（int_items__name_resolved）を採用。message_id は取得・出力とも不要（ソースに列が無い）。
with fct as (

    select * from {{ ref('fct_purchase_item') }}

),

items_raw as (

    select item_id, item_url, item_name, category_id
    from {{ ref('stg_items') }}

),

items_resolved as (

    select item_url, item_name
    from {{ ref('int_items__name_resolved') }}

),

categories as (

    select * from {{ ref('int_categories_flatten') }}

),

users as (

    select * from {{ ref('dim_user') }}

),

stores as (

    select * from {{ ref('dim_store') }}

),

final as (

    select
        -- ── テーブル定義.xlsx の23列 ──────────────────────────────
        fct.purchase_item_id                                as id,
        -- message_id                                       -- #2: 取得・出力とも不要（ソースに列が無い）
        fct.purchased_at,
        coalesce(stores.ec_site_name, 'Rakuten')            as ec_site_name,
        fct.unit_price,
        fct.amount,
        fct.total_price,
        users.user_id_hash,
        coalesce(items_resolved.item_name, items_raw.item_name) as item_name,   -- 名寄せ後（URL 無しは生の名前）
        items_raw.item_url,
        fct.destination_postal_code,
        stores.store_name,
        users.gender_name,
        users.age,
        users.age_category,                                 -- age から導出（age NULL → NULL）
        users.state_name,
        users.marriage_status,
        users.profession_name,
        users.occupation_name,
        categories.category_level_1,
        categories.category_level_2,
        categories.category_level_3,
        categories.category_level_4,
        -- ── 課題スライドの派生列 ──────────────────────────────────
        fct.purchased_at::date                              as full_date,    -- 購入日（例: 2023-04-02 09:00 → 2023-04-02）
        date_trunc('month', fct.purchased_at)::date         as month_date,   -- 購入月＝月初日 date型（→ 2023-04-01）
        users.region_name                                  as region,        -- 地方（8地方区分）
        fct.is_discount,                                                     -- 割引フラグ（item_name に「セール」を含む）
        fct.discount_amount                                                 -- 割引額（item_url 内の最大単価 − unit_price）
    from fct
    left join items_raw       on items_raw.item_id       = fct.item_id
    left join items_resolved  on items_resolved.item_url = items_raw.item_url
    left join categories      on categories.category_id  = items_raw.category_id
    left join users           on users.user_key          = fct.user_key
    left join stores          on stores.store_key        = fct.store_key
    where categories.category_level_1 is not null           -- instructor 回答④: カテゴリ1 NULL 行は削除

)

select * from final

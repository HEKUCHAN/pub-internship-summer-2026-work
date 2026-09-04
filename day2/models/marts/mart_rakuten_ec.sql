-- 大福帳: テーブル定義.xlsx の23列（message_id は取得・出力とも不要のためコメントで位置のみ）。
-- fct_purchase_item に全ディメンションを JOIN して平坦化したワイドテーブル（設計書 §6）。
-- grain: 1購入明細＝1行。instructor 回答④により category_level_1 が NULL の行は削除する
--        （CATEGORIES を category_id → parent_category_id で遡って第1階層に到達しない行。
--         実データでは item_id 欠損 or 商品の category_id 欠損の行、約22.6万行）。
with fct as (

    select * from {{ ref('fct_purchase_item') }}

),

dim_item as (

    select * from {{ ref('dim_item') }}

),

dim_user as (

    select * from {{ ref('dim_user') }}

),

dim_store as (

    select * from {{ ref('dim_store') }}

),

final as (

    select
        fct.purchase_item_id                                as id,
        -- message_id                                       -- #2: 取得・出力とも不要（ソースに列が無い）
        fct.purchased_at,
        coalesce(dim_store.ec_site_name, 'Rakuten')         as ec_site_name,
        fct.unit_price,
        fct.amount,
        fct.total_price,
        dim_user.user_id_hash,
        dim_item.item_name,                                 -- 名寄せ後の代表名（dim_item 由来）
        dim_item.item_url,
        fct.destination_postal_code,
        dim_store.store_name,
        dim_user.gender_name,
        dim_user.age,
        dim_user.age_category,                              -- age から導出（age NULL → NULL）
        dim_user.state_name,
        dim_user.marriage_status,
        dim_user.profession_name,
        dim_user.occupation_name,
        dim_item.category_level_1,
        dim_item.category_level_2,
        dim_item.category_level_3,
        dim_item.category_level_4
    from fct
    left join dim_item  on dim_item.item_key   = fct.item_key
    left join dim_user  on dim_user.user_key   = fct.user_key
    left join dim_store on dim_store.store_key  = fct.store_key
    where dim_item.category_level_1 is not null             -- instructor 回答④: カテゴリ1 NULL 行は削除

)

select * from final

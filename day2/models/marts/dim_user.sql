-- dim_user（設計書 §5.3）: 1ユーザ＝1行の素直なマスタ（履歴なし・§8）。
-- 派生: age_category（年代）= gene_definition シードに範囲 LEFT JOIN。
--       テーブル定義の仕様どおり age が NULL の場合は age_category も NULL（未マッチ）。
--       region_name（地方）= prefecture_region シード（都道府県→8地方）に LEFT JOIN。
with users as (

    select * from {{ ref('stg_users') }}

),

gene as (

    select * from {{ ref('gene_definition') }}

),

region as (

    select * from {{ ref('prefecture_region') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['users.user_id_hash']) }} as user_key,
        users.user_id_hash,
        users.gender_name,
        users.age,
        gene.gene as age_category,             -- age が NULL は未マッチ → NULL（テーブル定義の仕様）
        users.state_name,
        region.region_name,                    -- 未知の都道府県・空欄は未マッチ → NULL
        users.marriage_status,
        users.profession_name,
        users.occupation_name
    from users
    left join gene
        on users.age between gene.age_lower_limit and gene.age_upper_limit
    left join region
        on region.state_name = users.state_name

)

select * from final

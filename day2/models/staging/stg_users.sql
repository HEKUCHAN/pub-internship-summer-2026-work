-- 設計書 §5.0: USERS を 1:1 でリネーム・型そろえするだけ（加工はしない）
-- USER_ID は §3 命名規則よりナチュラルキーとして user_id_hash で保持する
-- AGE_CATEGORY はソース値を使わず dim_user で AGE から導出するため、ここでは取り込まない（§2 注記）
with source as (
    select * from {{ source('rakuten_ec', 'users') }}
),

renamed as (
    select
        user_id             as user_id_hash,
        gender_name,
        age,
        state_name,
        marriage_status,
        profession_name,
        occupation_name
    from source
)

select * from renamed

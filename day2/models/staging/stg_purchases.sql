-- 設計書 §5.0: PURCHASES を 1:1 でリネーム・型そろえするだけ（加工はしない）
-- USER_ID は stg_users と揃えてナチュラルキー user_id_hash で保持する（§3）
-- purchased_at はソースが TIMESTAMP_TZ。日付・月の導出は dim_date で行う（§5.2）
-- 設計書 §2/§6 の message_id は実ソース PURCHASES に列が存在しないため取り込めない
with source as (
    select * from {{ source('rakuten_ec', 'purchases') }}
),

renamed as (
    select
        purchase_id,
        purchased_at,
        user_id                     as user_id_hash,
        destination_postal_code
    from source
)

select * from renamed

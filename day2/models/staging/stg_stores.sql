-- 設計書 §5.0: STORES を 1:1 でリネームするだけ（加工はしない）
with source as (
    select * from {{ source('rakuten_ec', 'stores') }}
),

renamed as (
    select
        store_id,
        store_name,
        ec_site_id
    from source
)

select * from renamed

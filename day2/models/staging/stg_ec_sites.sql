-- 設計書 §5.0: EC_SITES を 1:1 でリネームするだけ（加工はしない）
with source as (
    select * from {{ source('rakuten_ec', 'ec_sites') }}
),

renamed as (
    select
        ec_site_id,
        ec_site_name
    from source
)

select * from renamed

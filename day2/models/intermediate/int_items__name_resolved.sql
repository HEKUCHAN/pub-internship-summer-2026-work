-- 名寄せ（設計書 §5.4 / §7）
-- 前提: 同一 item_url = 同一商品。表記揺れの主因は item_name 先頭の販促枠
--       （例: 【MAX30%offクーポン対象】, ＼期間限定★40%OFF／, 【6/4 20:00~限定!】…）。
-- 方針: 先頭の販促枠・装飾を落として素の商品名に寄せ、URL 単位で「最頻の掃除後名」を代表に採る。
-- grain: 1 item_url = 1 行。item_url が NULL の行は URL で名寄せできないため除外する
--        （実データで約 5 万行。カテゴリ NULL 除外と同様、下流ファクトからも自然に落ちる）。

with items as (

    select * from {{ ref('stg_items') }}
    where item_url is not null

),

cleaned as (

    select
        item_id,
        item_url,
        category_id,
        item_name,
        -- 先頭の販促枠・装飾を除去して素の商品名へ寄せる
        trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
            -- 全角スペース・NBSP を半角へ
            translate(item_name, '　' || char(160), '  '),
            -- 先頭にぶら下がる販促ブラケット（＼…／ / 【】［］（）〈〉《》≪≫）を繰り返し除去。
            -- 枠の中身は 80 文字までに制限し、商品名全体が 1 枠になっているケースは触らない
            '^([[:space:]]*(＼[^／]{0,80}／|[【［（(《≪][^]】］)）》≫]{0,80}[]】］)）》≫]))+', ''),
            -- 先頭に残った孤立ブラケット・記号（末尾の - は範囲指定と解釈されないよう最後に置く）
            '^[[:space:]】］）》≫【［（(《≪★☆♪!！?？/／・:：|｜~〜ー―－、。,.-]+', ''),
            -- 末尾の内部管理コード（_SS, _AD_SS, _S193 …）
            '([[:space:]]*_[A-Za-z0-9]{1,6}){1,4}[[:space:]]*$', ''),
            -- 連続空白を 1 個に
            '[[:space:]]+', ' '
        )) as item_name_clean
    from items

),

normalized as (

    select
        item_id,
        item_url,
        category_id,
        -- 掃除しすぎて壊れた場合（例: 商品名全体が 1 つの括弧）は素の名前へ退避
        case
            when length(item_name_clean) < 4
                then trim(regexp_replace(translate(item_name, '　' || char(160), '  '), '[[:space:]]+', ' '))
            else item_name_clean
        end as item_name_resolved
    from cleaned

),

name_frequency as (

    select
        item_url,
        item_name_resolved,
        count(*) as name_count
    from normalized
    group by 1, 2

),

-- URL ごとに代表名を 1 つ選ぶ: 最頻 → 短い → 文字コード順（決定的なタイブレーク）
representative as (

    select
        item_url,
        item_name_resolved as item_name
    from name_frequency
    qualify row_number() over (
        partition by item_url
        order by name_count desc, length(item_name_resolved) asc, item_name_resolved asc
    ) = 1

),

-- category_id は URL 内で一意（実データで衝突 0 件を確認済み）。代表 1 件を採る
url_category as (

    select
        item_url,
        min(category_id) as category_id
    from normalized
    group by 1

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['representative.item_url']) }} as item_key,
        representative.item_url,
        representative.item_name,
        url_category.category_id
    from representative
    left join url_category using (item_url)

)

select * from final

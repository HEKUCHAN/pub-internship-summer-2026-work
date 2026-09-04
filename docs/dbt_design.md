# 楽天EC 大福帳 テーブル設計書

先進情報プロジェクト演習 I ／ 楽天市場 購入データからの属性付与処理（Snowflake ＋ dbt 想定）

---

## 1. 目的と全体方針

第3正規化された元データ（`SHARED_DB.RAKUTEN_EC_RAW`）を加工し、分析用の**大福帳テーブル（1明細＝1行の非正規化ワイドテーブル）**を作成する。列構成は `テーブル定義.xlsx` に準拠し、課題要件で指定された派生属性（購入日・購入月・地方・年代・合計購入金額・割引フラグ・割引額・名寄せ）を付与する。

作り方は2層構成を採る。

1. **スタースキーマ（中間層）** … ファクト1本＋ディメンション4本に分けて組む。
2. **大福帳（最終マート）** … 上のスタースキーマを全部 JOIN して1枚に平坦化したもの。

> **要点：大福帳はスタースキーマを JOIN して平たくしたものそのもの。** スタースキーマを組んでおけば、最後に結合すれば大福帳になる。star を挟まず一発の SQL で大福帳を直接作ることもできる（`staging → 大福帳`）。本書は star を挟む構成で記述する。

最小粒度（grain）は元データの `PURCHASE_ITEMS`（購入1明細）。大福帳もファクトもこの粒度で1行になる。

---

## 2. 元データ（3NF・7テーブル）

`SHARED_DB.RAKUTEN_EC_RAW`（読み取り専用・与えられているもの）。

| テーブル | 主キー | 主な列 | 役割 |
|---|---|---|---|
| `USERS` | `USER_ID` | `GENDER_NAME`, `AGE`, `AGE_CATEGORY`, `STATE_NAME`, `MARRIAGE_STATUS`, `PROFESSION_NAME`, `OCCUPATION_NAME` | 購入者 |
| `EC_SITES` | `EC_SITE_ID` | `EC_SITE_NAME` | ECサイト（今回は rakuten のみ）|
| `STORES` | `STORE_ID` | `STORE_NAME`, `EC_SITE_ID`(FK) | 出店ショップ |
| `CATEGORIES` | `CATEGORY_ID` | `CATEGORY_NAME`, `CATEGORY_LEVEL`, `PARENT_CATEGORY_ID`(FK・自己参照) | 商品カテゴリ階層 |
| `ITEMS` | `ITEM_ID` | `ITEM_NAME`, `ITEM_URL`, `STORE_ID`(FK), `CATEGORY_ID`(FK) | 商品 |
| `PURCHASES` | `PURCHASE_ID` | `MESSAGE_ID`, `PURCHASED_AT`, `USER_ID`(FK), `DESTINATION_POSTAL_CODE` | 購入ヘッダ |
| `PURCHASE_ITEMS` | `PURCHASE_ITEM_ID` | `PURCHASE_ID`(FK), `ITEM_ID`(FK), `UNIT_PRICE`, `AMOUNT`, `TOTAL_PRICE` | 購入明細（＝grain）|

> **ER図と実ソース（`_sources.yml`）の差異：** `USERS` には ER図に無い `AGE_CATEGORY`（年齢カテゴリ）列が実在する。ただし課題要件は「年齢を10歳ごとにまとめる」＝自前で導出せよと明記しているため、本設計では `age_category` を `dim_user` で **AGE から導出**する方針を維持する（ソースの `AGE_CATEGORY` は使わない／必要なら導出結果の検算に使う）。また `PURCHASE_ITEMS.TOTAL_PRICE` は「UNIT_PRICE × AMOUNT」でソースに計算済みのため、`total_price` は自前計算・ソース値の通し、どちらでも可。

---

## 3. 命名規則

| 対象 | ルール | 例 |
|---|---|---|
| 層の接頭辞 | `stg_`（staging）→ `int_`（intermediate）→ `dim_` / `fct_`（marts）| `stg_items`, `int_categories_flatten`, `dim_item` |
| ディメンション | モノ＝名詞・単数で `dim_` | `dim_user`, `dim_item` |
| ファクト | コト＝出来事で `fct_` | `fct_purchase_item` |
| サロゲートキー | dbt で新規採番する一意ラベル `<対象>_key` | `user_key`, `item_key` |
| ナチュラルキー | 元データ本来のキーは名前を変えず保持 | `user_id_hash`, `item_url` |
| 外部キー | 参照先ディメンションの `<dim>_key` | `fct` の `user_key` |
| カラム全般 | snake_case・小文字。大福帳の物理名は `テーブル定義.xlsx` に厳密一致させる | `age_category`, `total_price` |

---

## 4. 配置スキーマ（Snowflake）

| 層 | 配置 | 備考 |
|---|---|---|
| 元データ | `SHARED_DB.RAKUTEN_EC_RAW` | dbt では `sources`（`_sources.yml`）として参照。読み取り専用 |
| staging / intermediate / marts | 自分の DB・スキーマ | dbt の target schema。開発中は個人スキーマ（例 `dbt_<名前>`）、公開用は marts スキーマ。層ごとにスキーマを分ける構成も可 |

---

## 5. スタースキーマ設計（中間層）

星の中心が `fct_purchase_item`、周囲を4つのディメンションが囲む。

```
            dim_date
                |
 dim_user ─ fct_purchase_item ─ dim_item
                |
           dim_store
```

### 5.0 staging（`stg_*`）— 7本

元7テーブルを1対1でリネーム・型そろえするだけの層。加工はしない。
`stg_users` / `stg_ec_sites` / `stg_stores` / `stg_categories` / `stg_items` / `stg_purchases` / `stg_purchase_items`。

### 5.1 `int_categories_flatten`（intermediate）

自己参照の `CATEGORIES` を `PARENT_CATEGORY_ID` で辿り、末端カテゴリごとに各階層名を横に展開する（自己結合 or 再帰CTE）。

| 物理名 | 型 | 種別 | 定義 |
|---|---|---|---|
| `category_id` | NUMBER | PK | 末端カテゴリID（`ITEMS.CATEGORY_ID` と対応）|
| `category_level_1` | VARCHAR | | 第1階層カテゴリ名 |
| `category_level_2` | VARCHAR | | 第2階層カテゴリ名 |
| `category_level_3` | VARCHAR | | 第3階層カテゴリ名 |
| `category_level_4` | VARCHAR | | 第4階層カテゴリ名 |

### 5.2 `dim_date`（日付ディメンション）

粒度：1日＝1行。`PURCHASES.PURCHASED_AT` の最小〜最大日付から生成、またはカレンダー表。

| 物理名 | 型 | 種別 | 定義 |
|---|---|---|---|
| `date_key` | NUMBER | PK（サロゲート）| 日付キー（例 `20230402`）|
| `full_date` | DATE | | **購入日** `purchased_at::date` |
| `month_date` | DATE | | **購入月＝月初日** `date_trunc('month', purchased_at)::date` |
| `year` | NUMBER | | 年 |
| `month` | NUMBER | | 月 |
| `day` | NUMBER | | 日 |
| `day_of_week` | VARCHAR | | 曜日（任意）|

### 5.3 `dim_user`（ユーザディメンション）

粒度：1ユーザ＝1行。履歴は持たない素直なマスタ（理由は §8）。

| 物理名 | 型 | 種別 | 定義 |
|---|---|---|---|
| `user_key` | NUMBER | PK（サロゲート）| 採番キー |
| `user_id_hash` | VARCHAR | ナチュラルキー | 元 `USER_ID` |
| `gender_name` | VARCHAR | | 性別（未回答は NULL）|
| `age` | NUMBER | | 年齢 |
| `age_category` | VARCHAR | 派生 | **年代**。`gene_definition` シード（年齢帯→年代）に `age between age_lower_limit and age_upper_limit` で LEFT JOIN。age が NULL は未マッチ→NULL。floor は使わない（20歳未満/80歳以上を特別扱いするため）。ソースの `AGE_CATEGORY` も使わない |
| `state_name` | VARCHAR | | 居住都道府県 |
| `region` | VARCHAR | 派生 | **地方**。都道府県 → 8地方の CASE マッピング |
| `marriage_status` | VARCHAR | | 婚姻状況 |
| `profession_name` | VARCHAR | | 業種 |
| `occupation_name` | VARCHAR | | 職業 |

### 5.4 `dim_item`（商品ディメンション・名寄せ後）

粒度：1商品＝`item_url` 単位で1行。**名寄せとカテゴリ1 NULL 除外をここで行う。**

| 物理名 | 型 | 種別 | 定義 |
|---|---|---|---|
| `item_key` | NUMBER | PK（サロゲート）| 採番キー |
| `item_url` | VARCHAR | ナチュラルキー | **名寄せの基準**（同一 URL＝同一商品。元の `ITEM_ID` は使わない）|
| `item_name` | VARCHAR | 派生 | 名寄せ後の代表商品名（`item_url` 単位で1つに寄せる）|
| `category_level_1` | VARCHAR | | 第1階層カテゴリ。**NULL の商品はこの表を作る段で除外** |
| `category_level_2` | VARCHAR | | 第2階層カテゴリ |
| `category_level_3` | VARCHAR | | 第3階層カテゴリ |
| `category_level_4` | VARCHAR | | 第4階層カテゴリ |
| `store_key` | NUMBER | FK → `dim_store` | 商品→店舗は固定のため保持（任意）|

### 5.5 `dim_store`（店舗ディメンション）

粒度：1店舗＝1行。`EC_SITES` を結合して非正規化する。

| 物理名 | 型 | 種別 | 定義 |
|---|---|---|---|
| `store_key` | NUMBER | PK（サロゲート）| 採番キー |
| `store_id` | NUMBER | ナチュラルキー | 元 `STORE_ID` |
| `store_name` | VARCHAR | | 店舗名 |
| `ec_site_name` | VARCHAR | | ECサイト名（`EC_SITES` を結合。今回は rakuten 固定）|

### 5.6 `fct_purchase_item`（購入明細ファクト・星の中心）

粒度：1明細＝1行（`PURCHASE_ITEMS` と同粒度）。

| 物理名 | 型 | 種別 | 定義 |
|---|---|---|---|
| `purchase_item_id` | NUMBER | 縮退ディメンション | 明細の自然キー（大福帳の `id` の元）|
| `purchase_id` | NUMBER | 縮退ディメンション | 注文単位 |
| `message_id` | VARCHAR | 縮退ディメンション | メール単位 |
| `date_key` | NUMBER | FK → `dim_date` | 購入日 |
| `user_key` | NUMBER | FK → `dim_user` | 購入者 |
| `item_key` | NUMBER | FK → `dim_item` | 商品（`item_url` 経由で解決）|
| `store_key` | NUMBER | FK → `dim_store` | 店舗 |
| `destination_postal_code` | VARCHAR | 縮退ディメンション | 配送先郵便番号 |
| `unit_price` | NUMBER | 事実（measure）| 商品単価。**取引ごとに変わるためファクトに置く** |
| `amount` | NUMBER | 事実（measure）| 購買数量 |
| `total_price` | NUMBER | 事実（measure）| **合計購入金額** `unit_price * amount` |
| `discount_amount` | NUMBER | 事実（measure）| **割引額** `item_url` 内の最大単価 − `unit_price` |
| `is_discount` | BOOLEAN | 事実（フラグ）| **割引フラグ** `item_name` に「セール」を含むか |

> **なぜ単価・割引額・割引フラグはディメンションでなくファクトなのか：** 割引額は「同一商品（同一 `item_url`）の最大単価との差」で定義され、同じ商品でも取引ごとに単価が異なることが前提。単価を商品マスタに入れると「1商品に単価が複数」となり破綻する。割引フラグも同じ URL の商品にセール表記が付く取引・付かない取引がありうるため、いずれも取引レベル＝ファクトに置く。

---

## 6. 大福帳（最終マート）

`fct_purchase_item` に全ディメンションを JOIN して平坦化したワイドテーブル。物理テーブル名は課題指定に従う（指定なければ `mart_rakuten_ec` 等）。

列は **`テーブル定義.xlsx` の23列**に、**課題要件で追加する派生5列**を加えた構成。

| # | 物理名 | 型 | 出所 | 定義 |
|---|---|---|---|---|
| 1 | `id` | VARCHAR | 定義 | レコード単位の通番（`purchase_item_id` 相当）|
| 2 | `message_id` | VARCHAR | 定義 | メール単位の一意ID |
| 3 | `purchased_at` | TIMESTAMP | 定義 | 購買日時 |
| 4 | `ec_site_name` | VARCHAR | 定義 | ECサイト名（rakuten 固定）|
| 5 | `unit_price` | NUMBER | 定義 | 商品単価 |
| 6 | `amount` | NUMBER | 定義 | 購買数量 |
| 7 | `total_price` | NUMBER | 定義 | 合計購買金額 `unit_price * amount` |
| 8 | `user_id_hash` | VARCHAR | 定義 | ユーザID |
| 9 | `item_name` | VARCHAR | 定義 | 商品名（名寄せ後の代表名）|
| 10 | `item_url` | VARCHAR | 定義 | 商品ページURL |
| 11 | `destination_postal_code` | VARCHAR | 定義 | 配送先郵便番号 |
| 12 | `store_name` | VARCHAR | 定義 | ストア名 |
| 13 | `gender_name` | VARCHAR | 定義 | 性別 |
| 14 | `age` | NUMBER | 定義 | 年齢 |
| 15 | `age_category` | VARCHAR | 定義 | 年代（10歳区切り）|
| 16 | `state_name` | VARCHAR | 定義 | 居住都道府県 |
| 17 | `marriage_status` | VARCHAR | 定義 | 婚姻状況 |
| 18 | `profession_name` | VARCHAR | 定義 | 業種 |
| 19 | `occupation_name` | VARCHAR | 定義 | 職業 |
| 20 | `category_level_1` | VARCHAR | 定義 | 商品カテゴリ第1階層（NULL 行は除外済み）|
| 21 | `category_level_2` | VARCHAR | 定義 | 商品カテゴリ第2階層 |
| 22 | `category_level_3` | VARCHAR | 定義 | 商品カテゴリ第3階層 |
| 23 | `category_level_4` | VARCHAR | 定義 | 商品カテゴリ第4階層 |
| 24 | `full_date` | DATE | 要件追加 | 購入日 |
| 25 | `month_date` | DATE | 要件追加 | 購入月（月初日）|
| 26 | `region` | VARCHAR | 要件追加 | 地方 |
| 27 | `is_discount` | BOOLEAN | 要件追加 | 割引フラグ |
| 28 | `discount_amount` | NUMBER | 要件追加 | 割引額 |

> `total_price`（合計購入金額）と `age_category`（年代）は定義に元からある列だが、課題要件はその**計算方法**を指定している（＝新規列ではなく算出ルール）。

---

## 7. 派生ルール一覧（課題要件の対応表）

| 要件（論理名 / 物理名） | 種類 | 置き場所 | ロジック |
|---|---|---|---|
| 購入日 `full_date` | 加工 | `dim_date` | `purchased_at::date` |
| 購入月 `month_date` | 加工 | `dim_date` | `date_trunc('month', purchased_at)::date`（月初日）|
| 地方 `region` | 加工 | `dim_user` | 都道府県→地方の対応を seed（例 `prefecture_region.csv`・47行）にして LEFT JOIN（巨大 CASE の代替）|
| 年代 `age_category` | 加工 | `dim_user` | `gene_definition` シードに範囲 LEFT JOIN（`age between age_lower_limit and age_upper_limit`）。区分は 20歳未満 / 20〜70代 / 80歳以上。floor ではない |
| 合計購入金額 `total_price` | 事実 | `fct_purchase_item` | `unit_price * amount` |
| 割引フラグ `is_discount` | 事実 | `fct_purchase_item` | `item_name ILIKE '%セール%'` |
| 割引額 `discount_amount` | 事実 | `fct_purchase_item` | `MAX(unit_price) OVER (PARTITION BY item_url) - unit_price` |
| 名寄せ後の商品名 `item_name` | 加工 | `dim_item` | `item_url` 単位で代表名を1つに集約 |
| カテゴリ1 NULL 行の除外 | 加工 | `dim_item` | `category_level_1 IS NOT NULL` の商品のみ残す → ファクトからも自動的に消える |
| カテゴリ1〜4 | 属性 | `dim_item` | `CATEGORIES` の自己参照階層を平坦化 |

> **地方・年代は seed（CSV）で持つ。** 対応表を `ref()` で JOIN する（markdown の表は仕様の記述で、実行時に参照されるのは seed）。年代は `gene_definition`、地方は `prefecture_region` を LEFT JOIN。`dbt_utils.mutually_exclusive_ranges` で年代 seed の隙間・重複を検査できる。

### つまずきやすい箇所の SQL（Snowflake 想定）

```sql
-- 購入月（月初日・date型）: 2023-04-02 09:00 → 2023-04-01
date_trunc('month', purchased_at)::date          as month_date,
purchased_at::date                                as full_date,

-- 年代：gene_definition シードに範囲 LEFT JOIN（floor ではない）
-- dim_user 側で:
--   left join {{ ref('gene_definition') }} g
--     on u.age between g.age_lower_limit and g.age_upper_limit
--   → g.gene as age_category（age NULL は未マッチ→NULL）

-- 割引フラグ・割引額（同一商品＝同一 item_url）
item_name ilike '%セール%'                                       as is_discount,
max(unit_price) over (partition by item_url) - unit_price        as discount_amount,

-- 名寄せ：item_url ごとに代表商品名を1つへ寄せる（例：最頻→同数なら最長）
row_number() over (partition by item_url order by cnt desc, length(item_name) desc) = 1
```

---

## 8. 補足：SCD（履歴保持）について

大福帳は「購入時点の年齢・住所」で集計したい要件（年代・地方）を持つため、本来は履歴保持型ディメンション（SCD Type 2）と相性が良い領域である。ただし元データ `USERS` には `AGE` と `STATE_NAME` が各ユーザ1つずつしか無く、変更履歴を復元しようがない。よって**今回の `dim_user` は履歴なしの素直なマスタとし、登録時点の値で割り切る**。SCD Type 2 は「住所・年齢の変更履歴が取れるデータであればこう組む」という発展形として位置づける。

---

## 9. ビルド順（積み上げ）

1. **staging** … ソース7表を1:1でクレンジング。
2. **intermediate / dimension** … `int_categories_flatten` → `dim_item`（名寄せ・カテゴリ1 NULL 除外）、`dim_user`（年代・地方の導出）、`dim_store`、`dim_date`。
3. **fact** … `fct_purchase_item`（`total_price` / `is_discount` / `discount_amount` を算出、各 `*_key` を付与）。
4. **mart（大福帳）** … ファクト＋全ディメンションを JOIN し、§6 の列に整形。

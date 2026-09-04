# 2日目ディレクトリ

## 実行前に

`.env` を読み込んでおくこと。`TEAM_NAME` の綴りが**そのまま作成される Snowflake のデータベース名・ウェアハウス名になる**ので、必ず目視で確認する。

```
$ source /workspaces/ipj-internship-summer-work/.env
$ echo "warehouse: ${TEAM_NAME}_WH / database: ${TEAM_NAME}_DB / schema: WORK_${SNOWFLAKE_USER}"
```

## パッケージのインストール
```
$ dbt deps
```

## 実行環境の作成

ウェアハウス・データベース・スキーマを作成する。
**まだ何も無い状態で実行できる dbt コマンドはこれだけ**なので、`dbt debug` や `dbt run` より先に実行すること。
何度実行しても安全（すでにあれば何もしない）。

```
$ dbt run-operation bootstrap
```

初回だけでなく、**`.env` の `TEAM_NAME` を変更したときも毎回実行する**。
忘れると `dbt run` が次のエラーになる。

```
Database error while listing schemas in database "<TEAM_NAME>_DB"
  002043 (02000): SQL compilation error:
  Object does not exist, or operation cannot be performed.
```

リポジトリルートから `dbt deps` → `bootstrap` → `dbt debug` をまとめて実行することもできる。

```
$ make day2-bootstrap
```

## 接続確認
```
$ dbt debug
```

## 実行
```
$ dbt run
```

## seedの作成
```
$ dbt seed
```

## documentの作成
```
$ dbt docs generate
$ dbt docs serve
```

## dbt run+dbt seedを同時に実行
```
$ dbt build
```

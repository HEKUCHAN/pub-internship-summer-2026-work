# pub-internship-2026-work
FY26 DATUM STUDIOインターンシップ作業用リポジトリ

# setup

## AWSのアカウントキーを発行

資料を参考にすること

## MFAデバイスの登録

IAMユーザーに仮想MFAデバイス（Google Authenticatorなどの認証アプリ）を登録する。
IAMコンソール → ユーザー → 対象ユーザー → 「セキュリティ認証情報」タブ →
 「MFAデバイスの割り当て」から、**デバイス名を入力**して認証アプリでQRコードを読み取る。

登録後、同じ「多要素認証 (MFA)」欄に識別子（ARN）が表示される。
このうち**登録時に入力したデバイス名の部分**を後で `.env` の `AWS_MFA_DEVICE_NAME` に設定するので控えておく。

```
arn:aws:iam::123456789012:mfa/<登録時に入力したデバイス名>
```

## .envの作成

雛形をコピーして、`<...>` の部分を配布資料の値に置き換える。


```
$ cp .env.example .env
```

| 値 | 用途 | 確認方法 |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | ロール引き受け元の認証情報 | スライドの手順で取得したアクセスキーの値 |
| `AWS_SECRET_ACCESS_KEY` | ロール引き受け元の認証情報 | スライドの手順で取得したシークレットアクセスキーの値 |
| `<アカウントID>` | ロール引き受け時の MFA 認証。MFA 登録時に自分で入力した名前がそのまま ARN になる | 12桁の数字、AWSコンソールよりユーザーの ARNから確認可能 |
| `<MFAデバイス名>` | ロール引き受け時の MFA 認証。MFA 登録時に自分で入力した名前がそのまま ARN になる | MFA設定した際のデバイス名 |
| `SNOWFLAKE_USER` | Snowflakeのユーザ名 | コンソール等からユーザ名を確認 |
| `PRIVATE_KEY_FILE` | Snowflakeキーペア認証用のキーファイルパス | 秘密鍵を配置したパスを記載|


# dbt
export TEAM_NAME='<チーム名を大文字アルファベットで、`TEAM_X`の形式（例: TEAM_A）>'



## 環境変数の読み込み
Snowflake / dbt 用の環境変数を読み込むため、以下コマンドをターミナルから実行する

```
$ source /workspaces/ipj-internship-summer-work/.env
$ echo 'source /workspaces/ipj-internship-summer-work/.env' >> ~/.bashrc
```

## 動作確認
```
$ aws sts get-session-token
```

Snowflake

```
$ python3 day1/snowflake_connect_sample.py
```

snowflake_connect_sample.py の実行で、パッケージが見つからないエラーになった場合、以下を実行して再度試してください。

```
$ uv sync
$ source .venv/bin/activate
```

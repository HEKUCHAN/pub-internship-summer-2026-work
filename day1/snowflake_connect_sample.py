import random
import string
import snowflake.connector
import textwrap
import os

account_name = "on44798-ds_5daysinternship_2026"
user = os.getenv("SNOWFLAKE_USER")
private_key_file=os.getenv("PRIVATE_KEY_FILE")
private_key_file_pwd=os.getenv("PRIVATE_KEY_FILE_PWD")  # パスフレーズ無しなら削除

# Snowflakeへの接続情報を設定
conn = snowflake.connector.connect(
    user=user, # 各自のユーザー名に変える
    account=account_name,
    authenticator="SNOWFLAKE_JWT",
    private_key_file=private_key_file,
    private_key_file_pwd=private_key_file_pwd,  # パスフレーズ無しなら削除
    role='INTERNSHIP_MEMBER',
    warehouse='TESTER_WH'
)

conn.cursor().execute(f"")
cur = conn.cursor()

try:
    cur.execute("select current_timestamp()")
    for col in cur:
        print('current_timestamp: {0}'.format(col[0]))
except snowflake.connector.errors.ProgrammingError as e:
    print(e)
finally:
    cur.close()

from pathlib import Path
import configparser
import mysql.connector

CONFIG_DIR = Path("/opt/Dail/config")
DATABASE_CONFIG = CONFIG_DIR / "databases.conf"

# --------------------------------------------------
# databases.conf 読み込み
# --------------------------------------------------

if not DATABASE_CONFIG.exists():
    raise FileNotFoundError(
        f"データベース設定ファイルが見つかりません: {DATABASE_CONFIG}"
    )

db_config = configparser.ConfigParser()
db_config.read(DATABASE_CONFIG, encoding="utf-8")

if "DATABASE" not in db_config:
    raise KeyError(
        f"{DATABASE_CONFIG} に [DATABASE] セクションがありません。"
    )

database = db_config["DATABASE"]

required_keys = (
    "host",
    "port",
    "user",
    "password",
    "database",
)

for key in required_keys:
    if key not in database:
        raise KeyError(
            f"[DATABASE] に '{key}' がありません。"
        )

# --------------------------------------------------
# MySQL 接続
# --------------------------------------------------

db = mysql.connector.connect(
    host=database.get("host"),
    port=database.getint("port", fallback=3306),
    user=database.get("user"),
    password=database.get("password"),
    database=database.get("database"),
)

cursor = db.cursor()

# --------------------------------------------------
# INI設定をMySQLへ登録
# --------------------------------------------------

for ini_file in CONFIG_DIR.glob("*.ini"):
    print(f"読み込み中: {ini_file.name}")

    config = configparser.ConfigParser()
    config.optionxform = str
    config.read(ini_file, encoding="utf-8")

    # DEFAULT セクション
    for key, value in config.defaults().items():
        cursor.execute(
            """
            INSERT INTO settings
                (section_name, setting_key, setting_value)
            VALUES
                (%s, %s, %s)
            ON DUPLICATE KEY UPDATE
                setting_value = VALUES(setting_value)
            """,
            ("DEFAULT", key, value),
        )

    # 通常セクション
    for section in config.sections():
        for key, value in config.items(section, raw=True):
            cursor.execute(
                """
                INSERT INTO settings
                    (section_name, setting_key, setting_value)
                VALUES
                    (%s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    setting_value = VALUES(setting_value)
                """,
                (section, key, value),
            )

db.commit()

cursor.close()
db.close()

print("設定をMySQLへ反映しました。")
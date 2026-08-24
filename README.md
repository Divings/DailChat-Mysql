# DailChat-Mysql

Dail は、Python と MySQL を利用した長期記憶・設定管理対応の AI ボットです。

セットアップスクリプトにより、Python 3.12、MySQL、Python 仮想環境、必要ライブラリ、Dail 本体、起動コマンドのセットアップをまとめて行えます。

Dail 本体は `/opt/Dail` にインストールされ、起動コマンドとして `/usr/local/bin/dail` が作成されます。

## 主な機能

* Python 3.12 ベース
* MySQL を利用した設定・データ管理
* 設定ファイルから MySQL への設定反映
* AI モデル・API キー設定
* 長期記憶設定
* Dropbox 連携設定
* 専用 Python 仮想環境
* `dail` コマンドによる起動

基本設定では、AI モデル、API キー、最大トークン数、ボット名などを設定できます。

## ディレクトリ構成

セットアップ後は、おおむね次の構成になります。

```text
/opt/Dail/
├── .venv/
├── config/
│   ├── config.ini
│   ├── databases.conf
│   ├── dropbox.ini
│   └── memory.ini
├── convert_conf.py
├── main.py
└── ...

/usr/local/bin/
└── dail
```

`src` ディレクトリ以下のファイル・ディレクトリは、セットアップ時に `/opt/Dail` へコピーされます。

## セットアップ

### 1. setup.sh に実行権限を付与

```bash
chmod +x setup.sh
```

### 2. セットアップを実行

```bash
./setup.sh
```

必要に応じて `sudo` が使用されます。

セットアップスクリプトでは、Python 3.12 が存在しない場合にインストールを行います。Ubuntu/Debian 系および Oracle Linux/RHEL/Rocky Linux/AlmaLinux 系を対象としています。

MySQL が存在しない場合もインストールし、利用可能な MySQL サービスを有効化・起動します。

## Dail グループ

セットアップ時に `dail` グループが作成されます。

セットアップを実行したユーザーは自動的に `dail` グループへ追加されます。

グループ追加後、現在のログインセッションに変更が反映されていない場合があります。

その場合は一度ログアウトして再ログインするか、次を実行してください。

```bash
newgrp dail
```

## Python 仮想環境

Dail 専用の Python 仮想環境は次の場所に作成されます。

```text
/opt/Dail/.venv
```

`requirements.txt` が存在する場合は、セットアップ時に仮想環境へ必要な Python ライブラリがインストールされます。

## MySQL の設定

Dail を利用する前に、MySQL 上で Dail が使用するデータベースとユーザーを作成してください。

データベース接続設定は次のファイルで管理します。

```text
/opt/Dail/config/databases.conf
```

設定例:

```ini
[DATABASE]
host = localhost
port = 3306
user = Users
password = Password
database = [Database]

[LEARNING]
enabled = true
importance_default = 3
```

データベース設定には、ホスト、ポート、MySQL ユーザー、パスワード、使用するデータベースを指定します。

`Users`、`Password`、`[Database]` はサンプル値です。実際の環境に合わせて変更してください。

> **注意**
>
> リポジトリに含まれているファイル名が `database.conf` の場合は、セットアップ後に `databases.conf` として配置するか、プログラム側とファイル名を統一してください。現在の `setup.sh` の案内では `databases.conf` を使用します。

## AI 基本設定

`config.ini` では Dail の基本設定を行います。

```ini
[DEFAULT]
model = gemini-3.5-flash-lite
gemini_api_key =
Max_Token = 1024
bot_name = ダイル
preload = 1
dvd_mode=0
pre_clear=0
```

`gemini_api_key` は初期状態では空欄です。利用する API キーを設定してください。

## 長期記憶設定

`memory.ini` では記憶関連の設定を行います。

```ini
[MEMORY]
max_memory = 5
```

現在のテンプレートでは `max_memory` が `5` に設定されています。

## Dropbox 設定

Dropbox 連携設定は `dropbox.ini` で管理します。

```ini
[DROPBOX]
enabled = false
app_key =
refresh_token =
memory_path = /AI Memory/gemini/memory.vlm
```

初期状態では Dropbox 連携は無効です。

`app_key` と `refresh_token` は空欄になっています。Dropbox 連携を使用する場合に設定してください。

## 設定を MySQL に反映する

MySQL のデータベース・ユーザーを作成し、`databases.conf` を設定した後、`convert_conf.py` を実行します。

```bash
cd /opt/Dail

./.venv/bin/python convert_conf.py
```

`convert_conf.py` は `/opt/Dail/config` 以下の `*.ini` ファイルを読み込み、設定内容を MySQL の `settings` テーブルへ反映します。

通常セクションについても、セクション名・設定キー・設定値として保存され、既存の項目については更新されます。

処理完了後はコミットされ、MySQL 接続が閉じられます。

## 起動

セットアップ完了後は、任意のディレクトリから次のコマンドで Dail を起動できます。

```bash
dail
```

`/usr/local/bin/dail` は `/opt/Dail/.venv/bin/python` を利用して `/opt/Dail/main.py` を起動します。

コマンドライン引数もそのまま `main.py` へ渡されます。

```bash
dail [arguments]
```

## インストール先

| 項目          | パス                    |
| ----------- | --------------------- |
| Dail 本体     | `/opt/Dail`           |
| Python 仮想環境 | `/opt/Dail/.venv`     |
| 設定          | `/opt/Dail/config`    |
| 起動コマンド      | `/usr/local/bin/dail` |
| 管理グループ      | `dail`                |

## 権限

`/opt/Dail` は `root:dail` を基本とした権限構成になっています。

ディレクトリには setgid が設定されるため、新しく作成されたファイルやディレクトリでも `dail` グループを継承しやすい構成です。

## 初回起動までの流れ

```text
リポジトリを取得
      ↓
chmod +x setup.sh
      ↓
./setup.sh
      ↓
MySQLユーザー作成
      ↓
MySQLデータベース作成
      ↓
/opt/Dail/config/databases.conf を設定
      ↓
必要な .ini ファイルを設定
      ↓
convert_conf.py を実行
      ↓
dail
```

## セキュリティ上の注意

API キー、Dropbox の認証情報、MySQL パスワードなどは秘密情報です。

実際の認証情報を設定した設定ファイルを、公開 Git リポジトリへそのままコミットしないでください。

特に以下の値は取り扱いに注意してください。

```text
gemini_api_key
app_key
refresh_token
DATABASE.password
```

配布用テンプレートでは、認証情報を空欄またはサンプル値のままにしておくことを推奨します。

## ライセンス

ライセンスについては、リポジトリに含まれるライセンスファイルを確認してください。

#!/bin/bash

set -e

INSTALL_DIR="/opt/Dail"
VENV_DIR="$INSTALL_DIR/.venv"
DAIL_GROUP="dail"
LAUNCHER="/usr/local/bin/dail"

echo "================================"
echo " Dail Setup"
echo "================================"

# --------------------------------------------------
# sudo / 実行ユーザー判定
# --------------------------------------------------

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

REAL_USER="${SUDO_USER:-$USER}"

echo "セットアップ実行ユーザー: $REAL_USER"

# --------------------------------------------------
# OS判定
# --------------------------------------------------

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "エラー: /etc/os-release が見つかりません。"
    exit 1
fi

echo "OS: $PRETTY_NAME"

# --------------------------------------------------
# Python 3.12
# --------------------------------------------------

if command -v python3.12 >/dev/null 2>&1; then
    echo "Python 3.12 はインストール済みです。"
else
    echo "Python 3.12 をインストールします。"

    case "$ID" in
        ubuntu|debian)
            $SUDO apt update
            $SUDO apt install -y \
                python3.12 \
                python3.12-venv
            ;;

        ol|rhel|rocky|almalinux)
            $SUDO dnf install -y \
                python3.12 \
                python3.12-pip
            ;;

        *)
            echo "エラー: 未対応OSです: $ID"
            exit 1
            ;;
    esac
fi

echo "Python:"
python3.12 --version

# --------------------------------------------------
# MySQL
# --------------------------------------------------

if command -v mysql >/dev/null 2>&1; then
    echo "MySQL はインストール済みです。"
else
    echo "MySQL をインストールします。"

    case "$ID" in
        ubuntu|debian)
            $SUDO apt update
            $SUDO apt install -y mysql-server
            ;;

        ol|rhel|rocky|almalinux)
            $SUDO dnf install -y mysql-server
            ;;

        *)
            echo "エラー: 未対応OSです: $ID"
            exit 1
            ;;
    esac
fi

# --------------------------------------------------
# MySQLサービス起動
# --------------------------------------------------

echo "MySQLサービスを確認します。"

if systemctl list-unit-files | grep -q '^mysqld.service'; then
    $SUDO systemctl enable --now mysqld

elif systemctl list-unit-files | grep -q '^mysql.service'; then
    $SUDO systemctl enable --now mysql

else
    echo "警告: MySQLサービスを検出できませんでした。"
fi

# --------------------------------------------------
# dail グループ作成
# --------------------------------------------------

if getent group "$DAIL_GROUP" >/dev/null 2>&1; then
    echo "グループ '$DAIL_GROUP' は既に存在します。"
else
    echo "グループ '$DAIL_GROUP' を作成します。"
    $SUDO groupadd "$DAIL_GROUP"
fi

# --------------------------------------------------
# セットアップ実行ユーザーを dail グループへ追加
# --------------------------------------------------

if id -nG "$REAL_USER" | grep -qw "$DAIL_GROUP"; then
    echo "$REAL_USER は既に $DAIL_GROUP グループに所属しています。"
else
    echo "$REAL_USER を $DAIL_GROUP グループへ追加します。"
    $SUDO usermod -aG "$DAIL_GROUP" "$REAL_USER"
fi

# --------------------------------------------------
# src確認
# --------------------------------------------------

if [ ! -d "src" ]; then
    echo "エラー: src ディレクトリが見つかりません。"
    exit 1
fi

# --------------------------------------------------
# /opt/Dail 作成
# --------------------------------------------------

echo "インストール先を作成します:"
echo "  $INSTALL_DIR"

$SUDO mkdir -p "$INSTALL_DIR"

# --------------------------------------------------
# src 配下をすべてコピー
# --------------------------------------------------

echo "Dail本体をコピーします。"

$SUDO cp -a src/. "$INSTALL_DIR/"

# --------------------------------------------------
# requirements.txt コピー
# --------------------------------------------------

if [ -f "requirements.txt" ]; then
    echo "requirements.txt をコピーします。"
    $SUDO cp requirements.txt "$INSTALL_DIR/requirements.txt"
else
    echo "警告: requirements.txt がありません。"
fi

# --------------------------------------------------
# 所有権・権限
# --------------------------------------------------

echo "所有グループを '$DAIL_GROUP' に設定します。"

$SUDO chown -R root:"$DAIL_GROUP" "$INSTALL_DIR"

# ディレクトリ
# root/dail = rwx
# その他 = r-x
# setgidで新規作成物もdailグループを継承
$SUDO find "$INSTALL_DIR" \
    -type d \
    -exec chmod 2775 {} \;

# 通常ファイル
# root/dail = rw
# その他 = r
$SUDO find "$INSTALL_DIR" \
    -type f \
    -exec chmod 664 {} \;

# --------------------------------------------------
# Python venv
# --------------------------------------------------

if [ ! -d "$VENV_DIR" ]; then
    echo "Python仮想環境を作成します:"
    echo "  $VENV_DIR"

    $SUDO python3.12 -m venv "$VENV_DIR"
else
    echo "Python仮想環境は既に存在します。"
fi

# venvをグループ管理可能にする
$SUDO chown -R root:"$DAIL_GROUP" "$VENV_DIR"

# ディレクトリだけsetgid
$SUDO find "$VENV_DIR" \
    -type d \
    -exec chmod 2775 {} \;

# --------------------------------------------------
# pip更新
# --------------------------------------------------

echo "pipを更新します。"

$SUDO "$VENV_DIR/bin/python" \
    -m pip install --upgrade pip

# --------------------------------------------------
# Pythonライブラリ
# --------------------------------------------------

if [ -f "$INSTALL_DIR/requirements.txt" ]; then
    echo "Pythonライブラリをインストールします。"

    $SUDO "$VENV_DIR/bin/python" \
        -m pip install \
        -r "$INSTALL_DIR/requirements.txt"
else
    echo "警告: requirements.txt がないため"
    echo "ライブラリのインストールをスキップします。"
fi

# pip実行後に所有グループを再調整
$SUDO chown -R root:"$DAIL_GROUP" "$VENV_DIR"

# --------------------------------------------------
# 起動スクリプト生成
# /usr/local/bin/dail
# --------------------------------------------------

echo "起動スクリプトを生成します:"
echo "  $LAUNCHER"

$SUDO tee "$LAUNCHER" >/dev/null <<'EOF'
#!/bin/bash

set -e

INSTALL_DIR="/opt/Dail"
PYTHON="$INSTALL_DIR/.venv/bin/python"
MAIN="$INSTALL_DIR/main.py"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "エラー: Dailがインストールされていません。"
    echo "見つからないディレクトリ: $INSTALL_DIR"
    exit 1
fi

if [ ! -x "$PYTHON" ]; then
    echo "エラー: DailのPython仮想環境が見つかりません。"
    echo "見つからないPython: $PYTHON"
    exit 1
fi

if [ ! -f "$MAIN" ]; then
    echo "エラー: Dailのmain.pyが見つかりません。"
    echo "見つからないファイル: $MAIN"
    exit 1
fi

cd "$INSTALL_DIR"

exec "$PYTHON" "$MAIN" "$@"
EOF

# --------------------------------------------------
# 起動スクリプト権限
# --------------------------------------------------

$SUDO chown root:root "$LAUNCHER"
$SUDO chmod 755 "$LAUNCHER"

# --------------------------------------------------
# 最終権限調整
# --------------------------------------------------

$SUDO chown -R root:"$DAIL_GROUP" "$INSTALL_DIR"

# /opt/Dail直下およびサブディレクトリはsetgid
$SUDO find "$INSTALL_DIR" \
    -type d \
    -exec chmod g+s {} \;

# --------------------------------------------------
# 完了
# --------------------------------------------------

echo
echo "================================"
echo " Dail セットアップ完了"
echo "================================"
echo
echo "インストール先:"
echo "  $INSTALL_DIR"
echo
echo "Python仮想環境:"
echo "  $VENV_DIR"
echo
echo "管理グループ:"
echo "  $DAIL_GROUP"
echo
echo "セットアップ実行ユーザー:"
echo "  $REAL_USER"
echo
echo "起動コマンド:"
echo "  dail"
echo
echo "Python:"
"$VENV_DIR/bin/python" --version
echo

if command -v mysql >/dev/null 2>&1; then
    echo "MySQL:"
    mysql --version
    echo
fi

echo "注意:"
echo "$REAL_USER を $DAIL_GROUP グループへ追加した場合、"
echo "現在のログインセッションにはまだ反映されていない場合があります。"
echo
echo "再ログインするか、以下を実行してください:"
echo
echo "  newgrp $DAIL_GROUP"
echo
echo "その後、Dailは以下で起動できます:"
echo
echo "  dail"
echo
echo "注意(その2): 必ずMySQLユーザーと使用するデータベースを作成し、"
echo "$INSTALL_DIR/config/databases.conf に接続情報を設定してから、"
echo "$INSTALL_DIR/convert_conf.py を実行してください。"
echo "これにより設定テンプレートの内容がMySQLの設定テーブルへ反映されます。"
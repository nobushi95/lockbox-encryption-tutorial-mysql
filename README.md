# lockbox 暗号化チュートリアル（MySQL + Docker Compose版）

[lockbox](https://github.com/ankane/lockbox) gemを使ったデータベース暗号化のチュートリアルプロジェクトです。

**RailsアプリとRubyスクリプトが同じマスターキーを共有し、アプリ間で暗号化・復号を相互運用できる**ことを学ぶのが目的です。

## 構成

```
.
├── docker-compose.yml
├── .env.example
├── rails_app/          # Rails 7.2 アプリ（ユーザー登録・一覧）
└── ruby_script/        # 純Rubyスクリプト（DBから直接復号して表示）
```

| サービス | 役割 |
|----------|------|
| `mysql` | データストア（MySQL 8.0） |
| `rails_app` | ユーザーをlockboxで暗号化して保存するRailsアプリ |
| `ruby_script` | RailsのORMを使わずにDBから直接復号するスクリプト |

## 学べること

- `has_encrypted` によるカラム単位の透過的暗号化
- `LOCKBOX_MASTER_KEY` を環境変数で管理する方法
- `Lockbox.attribute_key(table:, attribute:)` による属性別の鍵導出
- RailsのActive Recordを使わない純Rubyスクリプトからの復号（アプリ間の相互運用性）

## セットアップ

### 前提条件

- Docker / Docker Compose

### 手順

**1. 環境変数ファイルを作成する**

```bash
cp .env.example .env
```

**2. LOCKBOX_MASTER_KEY を生成して `.env` に設定する**

```bash
docker run --rm ruby:3.3.10-slim ruby -e "require 'lockbox'; puts Lockbox.generate_key"
```

出力された64文字の16進数文字列を `.env` の `LOCKBOX_MASTER_KEY=` に設定します。

```
LOCKBOX_MASTER_KEY=5899743dee623f3289b68790cff7df92dc197b6e9ca67b8a6f690157f3cfbf2b
```

**3. 起動する**

```bash
docker compose up --build
```

MySQLのヘルスチェック完了後にRailsが自動でDB作成・マイグレーションを実行します。

## 使い方

### ユーザーの登録

ブラウザで http://localhost:3000 を開き、フォームからユーザーを登録します。

または Rails コンソールから登録することもできます。

```bash
docker compose exec rails_app bundle exec rails console
```

```ruby
User.create!(name: "山田太郎", email: "taro@example.com", phone: "090-1234-5678")
```

### 暗号化の確認

MySQLに直接接続してカラムの値を確認します。

```bash
docker compose exec mysql mysql -u lockbox_user -plockbox_password lockbox_tutorial_development \
  -e "SELECT id, name_ciphertext, email_ciphertext FROM users;"
```

`*_ciphertext` カラムに平文とは異なる暗号化済みデータが格納されていることが確認できます。

### Rubyスクリプトで復号する

RailsのORMを使わず、純Rubyスクリプトで同じデータを復号します。

```bash
docker compose run --rm ruby_script
```

出力例:

```
ID: 1
名前: 山田太郎
Email: taro@example.com
電話番号: 090-1234-5678
作成日時: 2026-03-21 00:00:00 +0000
----------------------------------------
```

### テストを実行する

```bash
docker compose exec rails_app bundle exec rspec
```

## 仕組み

### 暗号化の流れ

```
LOCKBOX_MASTER_KEY（環境変数）
    ↓ HKDF（鍵導出）
Lockbox.attribute_key(table: "users", attribute: "name_ciphertext")
    ↓ AES-256-GCM
name_ciphertext カラムに保存
```

`has_encrypted :name` は内部で属性ごとに異なる鍵を導出するため、あるカラムの鍵が漏洩しても他のカラムへの影響がありません。

### アプリ間の相互運用

Rubyスクリプト側でも `Lockbox.attribute_key(table:, attribute:)` に**カラム名（`name_ciphertext`）**を渡すことで、Railsが暗号化したデータを復号できます。

```ruby
# rails_app: has_encrypted :name が内部で使う鍵導出
# ruby_script: 同じ鍵導出を明示的に再現する
box = Lockbox.new(
  key: Lockbox.attribute_key(table: "users", attribute: "name_ciphertext"),
  encode: true
)
box.decrypt_str(ciphertext)
```

> **注意:** `attribute:` には仮想属性名（`name`）ではなく、DBのカラム名（`name_ciphertext`）を渡す必要があります。

### `decrypt` vs `decrypt_str`

lockbox の `decrypt` メソッドは復号後のバイト列を `ASCII-8BIT` で返します。日本語などのマルチバイト文字列を扱う場合は `decrypt_str` を使うと `UTF-8` 文字列として取得できます。

```ruby
box.decrypt(ciphertext)     # => "山田太郎" (Encoding: ASCII-8BIT)
box.decrypt_str(ciphertext) # => "山田太郎" (Encoding: UTF-8)
```

## 環境変数

| 変数名 | 説明 |
|--------|------|
| `LOCKBOX_MASTER_KEY` | lockboxのマスターキー（64文字の16進数） |
| `MYSQL_ROOT_PASSWORD` | MySQLのrootパスワード |
| `MYSQL_DATABASE` | MySQLのデータベース名 |
| `MYSQL_USER` | MySQLのユーザー名 |
| `MYSQL_PASSWORD` | MySQLのパスワード |
| `DATABASE_HOST` | DBホスト名（Docker内では `mysql`） |
| `DATABASE_PORT` | DBポート番号 |
| `DATABASE_USERNAME` | Rails/スクリプトが使うDBユーザー名 |
| `DATABASE_PASSWORD` | Rails/スクリプトが使うDBパスワード |
| `DATABASE_NAME` | Rails/スクリプトが使うDB名 |

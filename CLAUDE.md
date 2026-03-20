# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

lockbox gem を使ったデータベース暗号化のチュートリアルプロジェクト。Rails 7.2 アプリと純 Ruby スクリプトが同じマスターキーを共有し、相互に復号できることを学ぶ。

## サービス構成

- **mysql**: MySQL 8.0 データストア
- **rails_app**: `has_encrypted` でユーザー情報を暗号化して保存するRailsアプリ（ポート3000）
- **ruby_script**: Active Record を使わず Mysql2 + Lockbox で直接復号するスクリプト（`profile: "script"` で条件付き実行）

## セットアップ

```bash
cp .env.example .env
# .env の LOCKBOX_MASTER_KEY を rails console で Lockbox.generate_key した値に書き換える
docker compose up --build
```

MySQL のヘルスチェック通過後、`entrypoint.sh` が `db:create` + `db:migrate` を自動実行する。

## よく使うコマンド

```bash
# テスト実行
docker compose exec rails_app bundle exec rspec

# 単一テストファイルの実行
docker compose exec rails_app bundle exec rspec spec/models/user_spec.rb

# 復号スクリプト実行
docker compose run --rm ruby_script

# Railsコンソール
docker compose exec rails_app bundle exec rails console

# マイグレーション
docker compose exec rails_app bundle exec rails db:migrate

# Rubocop
docker compose exec rails_app bundle exec rubocop
```

## アーキテクチャ

### 暗号化の仕組み

`has_encrypted :name, :email, :phone` を宣言すると、DBには `name_ciphertext` / `email_ciphertext` / `phone_ciphertext` カラムが保存される。アクセス時は仮想属性 `name` / `email` / `phone` として透過的に復号される。

マスターキーは `LOCKBOX_MASTER_KEY` 環境変数で管理し、`config/initializers/lockbox.rb` で `Lockbox.master_key` に設定する。

### 鍵導出（Rails↔純Rubyの相互運用ポイント）

属性ごとに HKDF で異なる鍵が導出される:

```ruby
key = Lockbox.attribute_key(table: "users", attribute: "name_ciphertext")
box = Lockbox.new(key: key, encode: true)
box.decrypt_str(Base64.decode64(ciphertext))  # UTF-8文字列として復号
```

`ruby_script/decrypt_users.rb` がこのパターンを実装しており、Rails を使わない環境でも同じデータを復号できることを示している。

### テスト構成

`spec/models/user_spec.rb` に4つのグループ:
1. バリデーション
2. 暗号化（`*_ciphertext` が平文と異なることを確認）
3. 復号（`User.find` で正しく復号されることを確認）
4. 鍵導出互換性（`Lockbox.attribute_key` で ruby_script と同じロジックで復号可能なことを確認）

DatabaseCleaner を使用（`transactional_fixtures: false`）。

## 環境変数

| 変数名 | 説明 |
|--------|------|
| `LOCKBOX_MASTER_KEY` | 64文字の16進数マスターキー |
| `MYSQL_ROOT_PASSWORD` | MySQLルートパスワード |
| `MYSQL_DATABASE` | MySQLデータベース名 |
| `MYSQL_USER` / `MYSQL_PASSWORD` | MySQLユーザー認証情報 |
| `DATABASE_HOST` / `DATABASE_PORT` | Rails側のDB接続先 |

`.env` ファイルは `.gitignore` で除外されている。`.env.example` を参照。

## ファイル構成

```
rails_app/          # Rails 7.2 アプリ
  app/models/user.rb               # has_encrypted 定義
  config/initializers/lockbox.rb   # マスターキー設定
  spec/models/user_spec.rb         # モデルテスト
ruby_script/
  decrypt_users.rb  # 純Ruby復号スクリプト
docker-compose.yml
.env.example
```

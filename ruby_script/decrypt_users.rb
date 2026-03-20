require "dotenv/load"
require "mysql2"
require "lockbox"

client = Mysql2::Client.new(
  host:     ENV.fetch("DATABASE_HOST", "127.0.0.1"),
  port:     ENV.fetch("DATABASE_PORT", "3306").to_i,
  username: ENV.fetch("DATABASE_USERNAME", "root"),
  password: ENV.fetch("DATABASE_PASSWORD", ""),
  database: ENV.fetch("DATABASE_NAME", "lockbox_tutorial_development"),
  encoding: "utf8mb4"
)

make_box = lambda do |table:, attribute:|
  Lockbox.new(
    key: Lockbox.attribute_key(table: table, attribute: attribute),
    encode: true
  )
end

name_box  = make_box.call(table: "users", attribute: "name_ciphertext")
email_box = make_box.call(table: "users", attribute: "email_ciphertext")
phone_box = make_box.call(table: "users", attribute: "phone_ciphertext")

rows = client.query("SELECT id, name_ciphertext, email_ciphertext, phone_ciphertext, created_at FROM users")

if rows.count == 0
  puts "ユーザーが存在しません。先にRailsアプリでユーザーを登録してください。"
  exit
end

rows.each do |row|
  begin
    puts "ID: #{row["id"]}"
    puts "名前: #{name_box.decrypt_str(row["name_ciphertext"])}"
    puts "Email: #{email_box.decrypt_str(row["email_ciphertext"])}"
    puts "電話番号: #{phone_box.decrypt_str(row["phone_ciphertext"])}"
    puts "作成日時: #{row["created_at"]}"
    puts "-" * 40
  rescue => e
    puts "ID #{row["id"]} の復号に失敗: #{e.message}"
  end
end

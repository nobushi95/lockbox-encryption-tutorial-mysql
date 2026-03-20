require "rails_helper"

RSpec.describe User, type: :model do
  describe "バリデーション" do
    it "name/email/phoneがすべて存在する場合は有効" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "nameが空の場合は無効" do
      user = build(:user, name: nil)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it "emailが空の場合は無効" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "phoneが空の場合は無効" do
      user = build(:user, phone: nil)
      expect(user).not_to be_valid
      expect(user.errors[:phone]).to include("can't be blank")
    end
  end

  describe "暗号化" do
    let!(:user) { create(:user, name: "田中花子", email: "hanako@example.com", phone: "080-9876-5432") }

    it "name_ciphertextは平文と異なる（暗号化されている）" do
      raw = User.connection.select_value("SELECT name_ciphertext FROM users WHERE id = #{user.id}")
      expect(raw).not_to eq("田中花子")
      expect(raw).not_to be_nil
    end

    it "email_ciphertextは平文と異なる（暗号化されている）" do
      raw = User.connection.select_value("SELECT email_ciphertext FROM users WHERE id = #{user.id}")
      expect(raw).not_to eq("hanako@example.com")
      expect(raw).not_to be_nil
    end

    it "phone_ciphertextは平文と異なる（暗号化されている）" do
      raw = User.connection.select_value("SELECT phone_ciphertext FROM users WHERE id = #{user.id}")
      expect(raw).not_to eq("080-9876-5432")
      expect(raw).not_to be_nil
    end
  end

  describe "復号" do
    let!(:user) { create(:user, name: "田中花子", email: "hanako@example.com", phone: "080-9876-5432") }

    it "User.findで正しい値が復号される" do
      found = User.find(user.id)
      expect(found.name).to eq("田中花子")
      expect(found.email).to eq("hanako@example.com")
      expect(found.phone).to eq("080-9876-5432")
    end
  end

  describe "鍵導出互換性（Rubyスクリプトとの互換）" do
    let!(:user) { create(:user, name: "田中花子", email: "hanako@example.com", phone: "080-9876-5432") }

    it "Lockbox.attribute_keyで導出した鍵で復号できる" do
      name_box = Lockbox.new(
        key: Lockbox.attribute_key(table: "users", attribute: "name_ciphertext"),
        encode: true
      )
      email_box = Lockbox.new(
        key: Lockbox.attribute_key(table: "users", attribute: "email_ciphertext"),
        encode: true
      )
      phone_box = Lockbox.new(
        key: Lockbox.attribute_key(table: "users", attribute: "phone_ciphertext"),
        encode: true
      )

      name_ct  = User.connection.select_value("SELECT name_ciphertext FROM users WHERE id = #{user.id}")
      email_ct = User.connection.select_value("SELECT email_ciphertext FROM users WHERE id = #{user.id}")
      phone_ct = User.connection.select_value("SELECT phone_ciphertext FROM users WHERE id = #{user.id}")

      expect(name_box.decrypt_str(name_ct)).to eq("田中花子")
      expect(email_box.decrypt_str(email_ct)).to eq("hanako@example.com")
      expect(phone_box.decrypt_str(phone_ct)).to eq("080-9876-5432")
    end
  end
end

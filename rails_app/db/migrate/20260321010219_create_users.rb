class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.text :name_ciphertext
      t.text :email_ciphertext
      t.text :phone_ciphertext
      t.timestamps
    end
  end
end

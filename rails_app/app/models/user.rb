class User < ApplicationRecord
  has_encrypted :name, :email, :phone
  validates :name, :email, :phone, presence: true
end

class User < ApplicationRecord
  has_secure_password

  has_many :receipt_uploads, dependent: :destroy
  has_many :owned_cards, dependent: :destroy
  has_many :cards, through: :owned_cards

  validates :username, presence: true, length: { maximum: 50 }, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
end


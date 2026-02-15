class Card < ApplicationRecord
  HANDS = %w[gu choki pa].freeze
  # normal: starter cards
  # bronze/silver/gold/legend: generated from receipts
  RARITIES = %w[normal bronze silver gold legend].freeze

  belongs_to :receipt_upload
  has_many :owned_cards, dependent: :destroy

  validates :name, presence: true
  validates :hand, inclusion: { in: HANDS }
  validates :flavor, presence: true
  validates :attack_power, inclusion: { in: [10, 20, 30, 40, 50] }
  validates :rarity, inclusion: { in: RARITIES }
end


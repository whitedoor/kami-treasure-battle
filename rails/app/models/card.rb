class Card < ApplicationRecord
  HANDS = %w[gu choki pa].freeze
  RARITIES = %w[bronze silver gold legend].freeze

  belongs_to :receipt_upload
  has_many :owned_cards, dependent: :destroy

  validates :name, presence: true
  validates :hand, inclusion: { in: HANDS }
  validates :flavor, presence: true
  validates :attack_power, inclusion: { in: [20, 30, 40, 50] }
  validates :rarity, inclusion: { in: RARITIES }
end


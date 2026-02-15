class User < ApplicationRecord
  require "securerandom"

  has_secure_password

  has_many :receipt_uploads, dependent: :destroy
  has_many :owned_cards, dependent: :destroy
  has_many :cards, through: :owned_cards

  validates :username, presence: true, length: { maximum: 50 }, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  after_create :grant_starter_cards!

  STARTER_CARDS = [
    { name: "グー", hand: "gu" },
    { name: "チョキ", hand: "choki" },
    { name: "パー", hand: "pa" }
  ].freeze

  private

  def grant_starter_cards!
    Card.transaction do
      STARTER_CARDS.each do |spec|
        bucket = "starter"
        object_key = [
          "starter_cards",
          id,
          "#{spec.fetch(:hand)}-#{SecureRandom.uuid}.jpg"
        ].join("/")

        receipt_upload = receipt_uploads.create!(
          status: "uploaded",
          gcs_bucket: bucket,
          gcs_object_key: object_key,
          gcs_uri: "gs://#{bucket}/#{object_key}"
        )

        card = Card.create!(
          receipt_upload: receipt_upload,
          name: spec.fetch(:name),
          hand: spec.fetch(:hand),
          flavor: "スターターカード",
          attack_power: 10,
          rarity: "normal"
        )

        owned_cards.create!(card: card)
      end
    end
  end
end


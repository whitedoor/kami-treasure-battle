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
        hand = spec.fetch(:hand)
        # NOTE: receipt_uploads has a unique index on [gcs_bucket, gcs_object_key],
        # so starter ReceiptUpload must always have a unique object_key per record.
        bucket = ENV["GCS_BUCKET"].presence || "starter"
        object_key = [
          Rails.env,
          "starter_cards",
          id,
          "#{hand}-#{SecureRandom.uuid}.jpg"
        ].join("/")
        gcs_uri = "gs://#{bucket}/#{object_key}"

        receipt_upload = receipt_uploads.create!(
          status: "uploaded",
          gcs_bucket: bucket,
          gcs_object_key: object_key,
          gcs_uri: gcs_uri
        )

        attrs = {
          receipt_upload: receipt_upload,
          name: spec.fetch(:name),
          hand: hand,
          flavor: "スターターカード",
          attack_power: 10,
          rarity: "normal"
        }

        # If GCS is configured, point the card image to the shared default object.
        if ENV["GCS_BUCKET"].present?
          default_key = CardDefaultImages.gcs_object_key_for(hand, env_prefix: Rails.env)
          attrs.merge!(
            artwork_status: "generated",
            artwork_bucket: ENV["GCS_BUCKET"].presence,
            artwork_object_key: default_key,
            artwork_gcs_uri: "gs://#{ENV['GCS_BUCKET']}/#{default_key}",
            artwork_mime_type: "image/png",
            artwork_model: "default"
          )
        end

        card = Card.create!(attrs)

        owned_cards.create!(card: card)
      end
    end
  end
end


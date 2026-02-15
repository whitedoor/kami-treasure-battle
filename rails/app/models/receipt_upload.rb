class ReceiptUpload < ApplicationRecord
  STATUSES = %w[uploaded extracted failed].freeze

  enum :status, {
    uploaded: "uploaded",
    extracted: "extracted",
    failed: "failed"
  }, validate: true

  has_one :card, dependent: :destroy

  validates :gcs_bucket, presence: true
  validates :gcs_object_key, presence: true
  validates :gcs_uri, presence: true
  validates :status, inclusion: { in: STATUSES }

  # uploaded の段階ではまだ抽出結果が空なので必須にしない。
  validates :extracted_json, presence: true, if: :extracted?
  validates :usage_json, presence: true, if: :extracted?
end


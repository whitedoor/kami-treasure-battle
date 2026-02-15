class CreateReceiptUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :receipt_uploads do |t|
      t.string :status, null: false, default: "uploaded"

      # GCS object info
      t.string :gcs_bucket, null: false
      t.string :gcs_object_key, null: false
      t.string :gcs_uri, null: false
      t.bigint :gcs_generation

      # Extraction result (Gemini)
      t.jsonb :extracted_json, null: false, default: {}
      t.text :raw_text
      t.string :model
      t.string :auth_mode
      t.string :location
      t.jsonb :usage_json, null: false, default: {}

      # Failure info
      t.text :error_message

      t.timestamps
    end

    add_index :receipt_uploads, :status
    add_index :receipt_uploads, [ :gcs_bucket, :gcs_object_key ], unique: true
  end
end


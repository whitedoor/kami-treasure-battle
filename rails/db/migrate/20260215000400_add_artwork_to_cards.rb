class AddArtworkToCards < ActiveRecord::Migration[8.1]
  def change
    change_table :cards, bulk: true do |t|
      t.string :artwork_status, null: false, default: "pending" # pending|generating|generated|failed
      t.text :artwork_error

      t.string :artwork_bucket
      t.string :artwork_object_key
      t.string :artwork_gcs_uri
      t.bigint :artwork_generation
      t.string :artwork_mime_type

      t.string :artwork_model
      t.text :artwork_prompt
    end

    add_index :cards, :artwork_status
  end
end


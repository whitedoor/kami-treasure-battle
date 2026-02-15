# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_15_000400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cards", force: :cascade do |t|
    t.string "artwork_bucket"
    t.text "artwork_error"
    t.string "artwork_gcs_uri"
    t.bigint "artwork_generation"
    t.string "artwork_mime_type"
    t.string "artwork_model"
    t.string "artwork_object_key"
    t.text "artwork_prompt"
    t.string "artwork_status", default: "pending", null: false
    t.integer "attack_power", null: false
    t.datetime "created_at", null: false
    t.string "flavor", default: "", null: false
    t.string "hand", null: false
    t.string "name", null: false
    t.string "rarity", null: false
    t.bigint "receipt_upload_id", null: false
    t.datetime "updated_at", null: false
    t.index ["artwork_status"], name: "index_cards_on_artwork_status"
    t.index ["attack_power"], name: "index_cards_on_attack_power"
    t.index ["rarity"], name: "index_cards_on_rarity"
    t.index ["receipt_upload_id"], name: "index_cards_on_receipt_upload_id", unique: true
  end

  create_table "owned_cards", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_owned_cards_on_card_id"
  end

  create_table "receipt_uploads", force: :cascade do |t|
    t.string "auth_mode"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.jsonb "extracted_json", default: {}, null: false
    t.string "gcs_bucket", null: false
    t.bigint "gcs_generation"
    t.string "gcs_object_key", null: false
    t.string "gcs_uri", null: false
    t.string "location"
    t.string "model"
    t.text "raw_text"
    t.string "status", default: "uploaded", null: false
    t.datetime "updated_at", null: false
    t.jsonb "usage_json", default: {}, null: false
    t.index ["gcs_bucket", "gcs_object_key"], name: "index_receipt_uploads_on_gcs_bucket_and_gcs_object_key", unique: true
    t.index ["status"], name: "index_receipt_uploads_on_status"
  end

  add_foreign_key "cards", "receipt_uploads"
  add_foreign_key "owned_cards", "cards"
end

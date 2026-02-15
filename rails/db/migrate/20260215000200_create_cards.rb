class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :receipt_upload, null: false, foreign_key: true, index: { unique: true }

      t.string :name, null: false
      t.string :hand, null: false # "gu" | "choki" | "pa"
      t.string :flavor, null: false, default: ""

      t.integer :attack_power, null: false
      t.string :rarity, null: false # "bronze" | "silver" | "gold" | "legend"

      t.timestamps
    end

    add_index :cards, :rarity
    add_index :cards, :attack_power
  end
end


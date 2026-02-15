class CreateOwnedCards < ActiveRecord::Migration[8.1]
  def change
    create_table :owned_cards do |t|
      t.references :card, null: false, foreign_key: true
      t.timestamps
    end
  end
end


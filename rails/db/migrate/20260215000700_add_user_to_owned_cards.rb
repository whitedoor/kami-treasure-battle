class AddUserToOwnedCards < ActiveRecord::Migration[8.1]
  def change
    # 既存データがある可能性があるため、まずはNULL許容で追加する。
    # 新規作成はアプリ側（OwnedCard.create!）で必ず user を付ける。
    add_reference :owned_cards, :user, null: true, foreign_key: true
    add_index :owned_cards, [ :user_id, :created_at ]
    add_index :owned_cards, [ :user_id, :card_id ], unique: true
  end
end


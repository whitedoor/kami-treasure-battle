class AddUserToReceiptUploads < ActiveRecord::Migration[8.1]
  def change
    # 既存データがある可能性があるため、まずはNULL許容で追加する。
    # 新規作成はアプリ側（ReceiptUpload.create!）で必ず user を付ける。
    add_reference :receipt_uploads, :user, null: true, foreign_key: true
    add_index :receipt_uploads, [ :user_id, :created_at ]
  end
end


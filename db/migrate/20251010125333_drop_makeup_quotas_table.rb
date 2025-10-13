class DropMakeupQuotasTable < ActiveRecord::Migration[8.0]
  def up
    drop_table :makeup_quotas, if_exists: true
  end

  def down
    create_table :makeup_quotas do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.integer :used_count, default: 0
      t.integer :max_count, default: 3

      t.timestamps
    end

    add_index :makeup_quotas, [:user_id, :year, :month], unique: true
  end
end

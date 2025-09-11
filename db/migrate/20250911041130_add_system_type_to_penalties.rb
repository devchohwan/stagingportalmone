class AddSystemTypeToPenalties < ActiveRecord::Migration[8.0]
  def change
    add_column :penalties, :system_type, :string, default: 'practice', null: false
    add_index :penalties, [:user_id, :year, :month, :system_type], unique: true, name: 'index_penalties_on_user_year_month_system'
    remove_index :penalties, name: 'index_penalties_on_user_id_and_year_and_month' if index_exists?(:penalties, [:user_id, :year, :month])
  end
end

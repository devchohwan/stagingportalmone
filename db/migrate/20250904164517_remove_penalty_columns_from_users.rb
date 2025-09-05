class RemovePenaltyColumnsFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :no_show_count, :integer
    remove_column :users, :cancel_count, :integer
  end
end

class AddRemainingPassesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :remaining_passes, :integer, default: 0, null: false
  end
end

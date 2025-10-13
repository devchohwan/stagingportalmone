class AddPassesExpireDateToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :passes_expire_date, :date
  end
end

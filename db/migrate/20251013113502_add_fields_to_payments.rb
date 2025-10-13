class AddFieldsToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :teacher, :string
    add_column :payments, :months, :integer
    add_column :payments, :discounts, :string
  end
end

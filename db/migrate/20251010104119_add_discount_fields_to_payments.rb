class AddDiscountFieldsToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :enrollment_id, :integer
    add_column :payments, :discount_items, :json
    add_column :payments, :discount_amount, :integer
    add_column :payments, :final_amount, :integer
  end
end

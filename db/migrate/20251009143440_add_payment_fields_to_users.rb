class AddPaymentFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :remaining_lessons, :integer
    add_column :users, :last_payment_date, :date
  end
end

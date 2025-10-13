class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject
      t.integer :period
      t.integer :amount
      t.integer :lessons
      t.date :payment_date

      t.timestamps
    end
  end
end

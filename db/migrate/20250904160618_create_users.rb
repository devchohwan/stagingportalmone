class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :password_digest, null: false
      t.string :status, default: 'pending'
      t.boolean :is_admin, default: false
      t.string :teacher
      t.integer :no_show_count, default: 0
      t.integer :cancel_count, default: 0

      t.timestamps
    end
    
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
  end
end

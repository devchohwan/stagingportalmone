class CreateMakeupRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :makeup_rooms do |t|
      t.string :name, null: false
      t.integer :number, null: false
      t.text :description
      t.boolean :has_outlet, default: false
      t.boolean :is_active, default: true
      
      t.timestamps
    end
    
    add_index :makeup_rooms, :number, unique: true
    add_index :makeup_rooms, :is_active
  end
end
